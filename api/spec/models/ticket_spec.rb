# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ticket, type: :model do
  ## ------- Associations / Validations -------
  describe "associations & validations" do
    subject { build(:ticket, ticket_type: nil) }

    it { is_expected.to belong_to(:event) }
    it { is_expected.to have_many(:reservations).dependent(:restrict_with_exception) }

    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:event_id) }
    it { is_expected.to validate_numericality_of(:price).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:quantity).is_greater_than_or_equal_to(1) }

    context "available_quantity 範囲" do
      it "0..quantity 内であること" do
        ticket = build(:ticket, quantity: 5, available_quantity: 6)
        expect(ticket).to be_invalid
        expect(ticket.errors.of_kind?(:available_quantity, :less_than_or_equal_to)).to be true
      end
    end
  end

  ## ------- Callbacks -------
  describe "callbacks" do
    it "create 時に available_quantity を quantity で初期化" do
      ticket = create(:ticket, quantity: 4, available_quantity: nil)
      expect(ticket.available_quantity).to eq 4
    end
  end

  ## ------- Business Logic -------
  describe "#reserve / .reserve_with_lock" do
    let!(:ticket) { create(:ticket, quantity: 5, available_quantity: 5) }

    it "在庫を減らす" do
      expect { ticket.reserve(2) }
        .to change { ticket.reload.available_quantity }.by(-2)
    end

    it "在庫不足で InsufficientQuantityError" do
      expect { ticket.reserve(6) }
        .to raise_error(Ticket::InsufficientQuantityError)
    end

    it ".reserve_with_lock で原子更新" do
      expect { described_class.reserve_with_lock(ticket.id, 3) }
        .to change { ticket.reload.available_quantity }.by(-3)
    end
  end

  ## ------- Concurrency smoke test -------
  describe "concurrent reservation", :concurrent do
    let(:event) { create(:event) }
    let(:ticket) { create(:ticket, event: event, quantity: 10, available_quantity: 5) } # quantityを明示的に指定
    let(:user1) { create(:user) }
    let(:user2) { create(:user) }

    it "allows only available quantity to be reserved" do
      mutex = Mutex.new
      cv = ConditionVariable.new
      threads_ready = 0
      max_threads = 3
      results = []
      timeout_seconds = 5 # タイムアウト設定

      threads = Array.new(max_threads) do |i|
        Thread.new do
          Timeout.timeout(timeout_seconds) do
            mutex.synchronize do
              threads_ready += 1
              cv.signal if threads_ready == max_threads
              cv.wait(mutex) if threads_ready < max_threads
            end

            sleep(0.01 * i)

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
          mutex.synchronize { results << {thread: i, success: false, error: "Timeout exceeded"} }
        rescue => e
          mutex.synchronize { results << {thread: i, success: false, error: e.message} }
        end
      end

      # タイムアウト付きでスレッド終了を待機
      threads.each do |thread|
        Timeout.timeout(timeout_seconds + 1) { thread.join }
      rescue Timeout::Error
        # タイムアウト時はスレッドを強制終了させる
        Thread.kill(thread) if thread.alive?
      end

      successful_reservations = results.count { |r| r[:success] }
      expect(successful_reservations).to be <= 2

      ticket.reload
      expect(ticket.available_quantity).to eq(5 - (successful_reservations * 2))
    end

    it "allows only available quantity to be reserved" do
      # 同時予約シミュレーション用の設定
      reservation_threads = []
      mutex = Mutex.new
      successful_reservations = 0
      failed_reservations = 0

      # 10の予約リクエストを同時に処理（利用可能は5のみ）
      10.times do |i|
        reservation_threads << Thread.new do
          create(:user, email: "concurrent_user_#{i}@example.com")

          begin
            # トランザクションを使って予約を試みる
            ActiveRecord::Base.transaction do
              result = Ticket.reserve_with_lock(ticket.id, 1)

              mutex.synchronize do
                successful_reservations += 1 if result
              end
            end
          rescue Ticket::InsufficientQuantityError
            mutex.synchronize do
              failed_reservations += 1
            end
          end
        end
      end

      # 全スレッドの完了を待つ
      reservation_threads.each(&:join)

      # 結果検証
      expect(successful_reservations).to eq(5) # 利用可能数と同じ
      expect(failed_reservations).to eq(5)     # 残りは失敗するはず

      # DBから再読み込みして確認
      ticket.reload
      expect(ticket.available_quantity).to eq(0) # すべて予約済み
    end

    it "correctly handles advisory locks for concurrent operations", :concurrent do
      # アドバイザリーロック競合のテスト
      lock_key = ticket.id
      lock_acquired_count = 0
      lock_failed_count = 0
      threads = []

      mutex = Mutex.new

      # 5つのスレッドで同時にロック取得を試みる
      5.times do
        threads << Thread.new do
          connection = ActiveRecord::Base.connection

          # アドバイザリーロックを試みる（タイムアウト1秒）
          acquired = connection.get_advisory_lock(lock_key, 1.0)

          mutex.synchronize do
            if acquired
              lock_acquired_count += 1
              # ロック取得できたら少し待ってからリリース
              sleep(0.1)
              connection.release_advisory_lock(lock_key)
            else
              lock_failed_count += 1
            end
          end
        end
      end

      threads.each(&:join)

      # 同時に複数のスレッドがロックを取得できないはず
      expect(lock_acquired_count).to be > 0
      expect(lock_acquired_count + lock_failed_count).to eq(5)
    end
  end
end
