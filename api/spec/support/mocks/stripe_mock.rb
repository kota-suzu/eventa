# frozen_string_literal: true

# Stripeのモッククラス
# テスト時にStripe API呼び出しをモック化するためのクラス
module Mocks
  class Stripe
    class << self
      # テスト環境用のモック設定
      def setup
        # 既にモック化されている場合は何もしない
        return if @already_mocked

        if defined?(::Stripe) && !defined?(OriginalStripe)
          # 本物のStripeモジュールをバックアップ
          Object.const_set(:OriginalStripe, ::Stripe)

          # モッククラスを定義
          stripe_mock = Module.new do
            module_function

            # Customer関連のモックメソッド
            def create_customer(email:, name:, token: nil, metadata: {})
              {
                id: "cus_#{SecureRandom.hex(10)}",
                email: email,
                name: name,
                metadata: metadata,
                created: Time.now.to_i
              }
            end

            # Charge関連のモックメソッド
            def create_charge(amount:, currency: "jpy", customer_id: nil, token: nil, description: nil, metadata: {})
              # 金額のバリデーション
              raise "Invalid amount" if amount <= 0

              # カードエラーシミュレーション
              if token == "tok_chargeDeclined" || token == "tok_chargeDeclinedInsufficientFunds"
                error = {message: "Your card was declined.", type: "card_error", code: "card_declined"}
                raise ::Stripe::CardError.new(error[:message], error[:code], error[:type])
              end

              # 成功レスポンス
              {
                id: "ch_#{SecureRandom.hex(10)}",
                object: "charge",
                amount: amount,
                currency: currency,
                customer: customer_id,
                description: description,
                metadata: metadata,
                created: Time.now.to_i,
                status: "succeeded"
              }
            end

            # Refund関連のモックメソッド
            def create_refund(charge_id:, amount: nil, reason: nil, metadata: {})
              {
                id: "re_#{SecureRandom.hex(10)}",
                object: "refund",
                amount: amount,
                charge: charge_id,
                reason: reason,
                metadata: metadata,
                created: Time.now.to_i,
                status: "succeeded"
              }
            end

            # その他必要に応じてメソッドを追加
          end

          # モジュールをセット
          Object.const_set(:Stripe, stripe_mock)

          # 既にモック化されたことを記録
          @already_mocked = true
        end
      end

      # モック解除
      def teardown
        if defined?(OriginalStripe) && @already_mocked
          Object.const_set(:Stripe, OriginalStripe)
          Object.send(:remove_const, :OriginalStripe)
          @already_mocked = false
        end
      end
    end
  end
end
