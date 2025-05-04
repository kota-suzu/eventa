# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentService do
  # モック実装と実際の実装のインターフェースを合わせた

  let(:user) { create(:user) }

  # テスト開始前にPaymentServiceをモック化
  before(:all) do
    Mocks::PaymentService.setup
  end

  # テスト終了後にモックを解除
  after(:all) do
    Mocks::PaymentService.teardown
  end

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
        # 各テストで新しい予約を作成
        reservation = create(:reservation, user: user, total_price: 2000, status: "pending")

        service = PaymentService.new(reservation, payment_params)
        result = service.process

        # 成功したことを確認
        expect(result).to be_a(Mocks::MockResult)
        expect(result.success?).to be true
        expect(result.transaction_id).to match(/^ch_/)

        # 予約を再読み込み
        reservation.reload

        # ステータスが更新されていることを確認
        expect(reservation.status).to eq("confirmed")
      end

      it "決済が失敗する場合" do
        # 各テストで新しい予約を作成
        reservation = create(:reservation, user: user, total_price: 2000, status: "pending")

        # 失敗するトークンに変更
        failed_params = payment_params.merge(token: "tok_fail")

        service = PaymentService.new(reservation, failed_params)
        result = service.process

        # 失敗したことを確認
        expect(result).to be_a(Mocks::MockResult)
        expect(result.success?).to be false
        expect(result.error_message).to eq("カードが拒否されました")

        # 予約を再読み込み
        reservation.reload

        # ステータスが更新されていることを確認
        expect(reservation.status).to eq("payment_failed")
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
        reservation = create(:reservation, user: user, total_price: 2000)
        service = PaymentService.new(reservation, payment_params)
        result = service.process

        expect(result).to be_a(Mocks::MockResult)
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
        reservation = create(:reservation, user: user, total_price: 2000)
        service = PaymentService.new(reservation, payment_params)
        result = service.process

        expect(result).to be_a(Mocks::MockResult)
        expect(result.success?).to be false
        expect(result.error_message).to eq("無効な支払い方法です")
      end
    end
  end
end
