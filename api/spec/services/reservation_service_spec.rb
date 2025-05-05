# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReservationService do
  let(:user) { create(:user) }
  let(:event) { create(:event) }
  let(:ticket) { create(:ticket, event: event, quantity: 10, available_quantity: 10) }

  describe ".call!" do
    context "with valid params" do
      let(:valid_params) do
        {
          ticket_id: ticket.id,
          quantity: 2,
          payment_method: "credit_card"
        }
      end

      it "creates a reservation" do
        expect {
          described_class.call!(user, valid_params)
        }.to change(Reservation, :count).by(1)
      end

      it "decreases the ticket available quantity" do
        expect {
          described_class.call!(user, valid_params)
        }.to change { ticket.reload.available_quantity }.by(-2)
      end

      it "returns the created reservation" do
        reservation = described_class.call!(user, valid_params)
        expect(reservation).to be_a(Reservation)
        expect(reservation.user).to eq(user)
        expect(reservation.ticket).to eq(ticket)
        expect(reservation.quantity).to eq(2)
        expect(reservation.payment_method).to eq("credit_card")
        expect(reservation.status).to eq("pending")
      end
    end

    context "with invalid params" do
      it "raises error when ticket is not found" do
        invalid_params = {ticket_id: 9999, quantity: 1, payment_method: "credit_card"}

        expect {
          described_class.call!(user, invalid_params)
        }.to raise_error(ReservationService::Error) do |error|
          expect(error.message).to eq("チケットが見つかりません")
        end
      end

      it "raises error when quantity is more than available" do
        invalid_params = {ticket_id: ticket.id, quantity: 11, payment_method: "credit_card"}

        expect {
          described_class.call!(user, invalid_params)
        }.to raise_error(ReservationService::Error) do |error|
          expect(error.message).to match(/在庫が不足しています/)
        end
      end

      it "raises error when quantity is less than or equal to 0" do
        invalid_params = {ticket_id: ticket.id, quantity: 0, payment_method: "credit_card"}

        expect {
          described_class.call!(user, invalid_params)
        }.to raise_error(ReservationService::Error) do |error|
          expect(error.message).to eq("数量は1以上を指定してください")
        end
      end
    end

    context "with concurrency" do
      it "handles race conditions correctly", :concurrent do
        # 並列予約をシミュレート
        threads = []
        3.times do
          threads << Thread.new do
            described_class.call!(user, {ticket_id: ticket.id, quantity: 3, payment_method: "credit_card"})
          rescue ReservationService::Error => e
            e.message
          end
        end

        # すべてのスレッドが終了するのを待つ
        results = threads.map(&:value)

        # 在庫が10枚なので、3人が3枚ずつ予約しようとすると、1人は失敗するはず
        successful_reservations = results.count { |r| r.is_a?(Reservation) }
        error_messages = results.select { |r| r.is_a?(String) }

        # 作成できたのは最大3件まで
        expect(successful_reservations).to be <= 3
        # 失敗したケースでは在庫不足エラーが出るはず
        expect(error_messages).to all(match(/在庫が不足しています/)) if error_messages.any?

        # 最終的な在庫数は正確
        ticket.reload
        expected_remaining = [0, 10 - (successful_reservations * 3)].max
        expect(ticket.available_quantity).to eq(expected_remaining)
      end
    end
  end
end
