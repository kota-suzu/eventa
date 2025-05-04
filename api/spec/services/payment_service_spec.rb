# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentService do
  let(:user) { create(:user) }
  let(:reservation) { create(:reservation, user: user, total_price: 2000) }

  describe "#process" do
    context "クレジットカード決済" do
      let(:payment_params) do
        {
          method: "credit_card",
          token: "tok_visa",
          amount: 2000
        }
      end

      it "決済が成功する" do
        # Stripeモックを設定
        charge = double("Stripe::Charge")
        allow(Stripe::Charge).to receive(:create).and_return(charge)
        allow(charge).to receive(:id).and_return("ch_123456")
        allow(charge).to receive(:status).and_return("succeeded")

        service = PaymentService.new(reservation, payment_params)
        result = service.process

        expect(result.success?).to be true
        expect(result.transaction_id).to eq("ch_123456")
        expect(reservation.reload.status).to eq("confirmed")
      end

      it "決済が失敗する場合" do
        # Stripeエラーをモック - 新しいAPI形式
        error_mock = double("Stripe::Error", message: "カードが拒否されました")
        allow(Stripe::Charge).to receive(:create).and_raise(Stripe::CardError.new("カードが拒否されました", {error: error_mock}))

        service = PaymentService.new(reservation, payment_params)
        result = service.process

        expect(result.success?).to be false
        expect(result.error_message).to include("カードが拒否されました")
        expect(reservation.reload.status).to eq("payment_failed")
      end
    end

    context "銀行振込決済" do
      let(:payment_params) do
        {
          method: "bank_transfer",
          amount: 2000
        }
      end

      it "支払い情報が生成される" do
        service = PaymentService.new(reservation, payment_params)
        result = service.process

        expect(result.success?).to be true
        expect(result.transaction_id).to include("bank_transfer_")
      end
    end

    context "不正な支払い方法" do
      let(:payment_params) do
        {
          method: "invalid_method",
          amount: 2000
        }
      end

      it "エラーを返す" do
        service = PaymentService.new(reservation, payment_params)
        result = service.process

        expect(result.success?).to be false
        expect(result.error_message).to eq("無効な支払い方法です")
      end
    end
  end
end
