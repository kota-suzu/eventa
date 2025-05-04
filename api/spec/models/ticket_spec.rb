# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ticket, type: :model do
  ## ------- Associations / Validations -------
  describe "associations & validations" do
    subject { build(:ticket) }

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
    let(:ticket) { create(:ticket, event: event, available_quantity: 5) }
    let(:user1) { create(:user) }
    let(:user2) { create(:user) }

    it "allows only available quantity to be reserved" do
      mutex = Mutex.new
      cv = ConditionVariable.new
      threads_ready = 0
      max_threads = 3
      results = []

      threads = Array.new(max_threads) do |i|
        Thread.new do
          mutex.synchronize do
            threads_ready += 1
            cv.signal if threads_ready == max_threads
            cv.wait(mutex) if threads_ready < max_threads
          end

          begin
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
          rescue => e
            mutex.synchronize { results << {thread: i, success: false, error: e.message} }
          end
        end
      end

      threads.each(&:join)

      successful_reservations = results.count { |r| r[:success] }
      expect(successful_reservations).to be <= 2

      ticket.reload
      expect(ticket.available_quantity).to eq(5 - (successful_reservations * 2))
    end
  end
end
