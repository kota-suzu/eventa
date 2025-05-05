# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ticket, type: :model do
  ## ------- アソシエーション / バリデーション -------
  describe "アソシエーションとバリデーション" do
    subject { build(:ticket, ticket_type: nil) }

    it { is_expected.to belong_to(:event) }
    it { is_expected.to have_many(:reservations).dependent(:restrict_with_exception) }

    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:event_id) }
    it { is_expected.to validate_numericality_of(:price).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:quantity).is_greater_than_or_equal_to(1) }

    context "available_quantity の範囲" do
      it "0..quantity 内であること" do
        ticket = build(:ticket, quantity: 5, available_quantity: 6)
        expect(ticket).to be_invalid
        expect(ticket.errors.of_kind?(:available_quantity, :less_than_or_equal_to)).to be true
      end
    end
  end

  ## ------- コールバック -------
  describe "コールバック" do
    it "create 時に available_quantity を quantity で初期化する" do
      ticket = create(:ticket, quantity: 4, available_quantity: nil)
      expect(ticket.available_quantity).to eq 4
    end
  end

  ## ------- ビジネスロジック -------
  describe "#reserve および .reserve_with_lock" do
    let!(:ticket) { create(:ticket, quantity: 5, available_quantity: 5) }

    it "在庫を減少させる" do
      expect { ticket.reserve(2) }
        .to change { ticket.reload.available_quantity }.by(-2)
    end

    it "在庫不足の場合は InsufficientQuantityError を発生させる" do
      expect { ticket.reserve(6) }
        .to raise_error(Ticket::InsufficientQuantityError)
    end

    it ".reserve_with_lock で原子更新する" do
      expect { described_class.reserve_with_lock(ticket.id, 3) }
        .to change { ticket.reload.available_quantity }.by(-3)
    end
  end

  ## ------- 同時実行テスト（スモーク） -------
  describe "同時予約 (concurrent reservation)", :concurrent do
    let(:event) { create(:event) }
    let(:ticket) { create(:ticket, event: event, quantity: 10, available_quantity: 5) }

    it "利用可能数を超えた予約は失敗する" do
      mutex = Mutex.new
      cv = ConditionVariable.new
      threads_ready = 0
      max_threads = 3
      results = []
      timeout_seconds = 5

      threads = Array.new(max_threads) do |i|
        Thread.new do
          Timeout.timeout(timeout_seconds) do
            mutex.synchronize do
              threads_ready += 1
              cv.signal if threads_ready == max_threads
              cv.wait(mutex) if threads_ready < max_threads
            end

            sleep(0.01 * i) # スレッドごとに少し遅延を加える

            Ticket.transaction do
              t = Ticket.lock.find(ticket.id)

              if t.available_quantity >= 2
                t.decrement!(:available_quantity, 2)
                mutex.synchronize { results << {thread: i, success: true, remaining: t.available_quantity} }
              else
                mutex.synchronize { results << {thread: i, success: false, remaining: t.available_quantity} }
              end
            end
          end
        rescue Timeout::Error
          mutex.synchronize { results << {thread: i, success: false, error: "タイムアウト"} }
        rescue => e
          mutex.synchronize { results << {thread: i, success: false, error: e.message} }
        end
      end

      threads.each do |th|
        Timeout.timeout(timeout_seconds + 1) { th.join }
      rescue Timeout::Error
        Thread.kill(th) if th.alive?
      end

      successful = results.count { |r| r[:success] }
      expect(successful).to be <= 2

      ticket.reload
      expect(ticket.available_quantity).to eq(5 - (successful * 2))
    end

    it "reserve_with_lock を用いた同時予約でも利用可能数を超えない" do
      threads = []
      mutex = Mutex.new
      success = 0
      failure = 0

      10.times do |i|
        threads << Thread.new do
          create(:user, email: "concurrent_user_#{i}@example.com")
          begin
            ActiveRecord::Base.transaction do
              Ticket.reserve_with_lock(ticket.id, 1)
              mutex.synchronize { success += 1 }
            end
          rescue Ticket::InsufficientQuantityError
            mutex.synchronize { failure += 1 }
          end
        end
      end

      threads.each(&:join)

      expect(success).to eq 5
      expect(failure).to eq 5

      ticket.reload
      expect(ticket.available_quantity).to eq 0
    end

    it "アドバイザリーロックで同時処理を適切に制御する" do
      lock_key = ticket.id
      acquired_count = 0
      failed_count = 0
      threads = []
      mutex = Mutex.new

      5.times do
        threads << Thread.new do
          conn = ActiveRecord::Base.connection
          acquired = conn.get_advisory_lock(lock_key, 1.0)

          mutex.synchronize do
            if acquired
              acquired_count += 1
              sleep 0.1
              conn.release_advisory_lock(lock_key)
            else
              failed_count += 1
            end
          end
        end
      end

      threads.each(&:join)

      expect(acquired_count).to be > 0
      expect(acquired_count + failed_count).to eq 5
    end
  end
end
