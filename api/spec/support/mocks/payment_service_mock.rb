# frozen_string_literal: true

# PaymentServiceのモッククラス
# テスト時に決済サービスをモック化するためのクラス
module Mocks
  class PaymentService
    class << self
      # テスト環境用のモック設定
      def setup
        # 本番のPaymentServiceクラスをバックアップ
        if Object.const_defined?(:PaymentService) && !Object.const_defined?(:OriginalPaymentService)
          Object.const_set(:OriginalPaymentService, PaymentService)
        end

        # モッククラスの定義
        payment_service_mock = Class.new do
          def self.process_payment(reservation_id:, card_token: nil, method: "credit_card")
            reservation = Reservation.find_by(id: reservation_id)

            # 基本的なバリデーション
            return {success: false, error: "予約が見つかりません"} unless reservation

            # テスト用の支払い成功/失敗シミュレーション
            if card_token == "tok_visa" || method == "bank_transfer"
              # 決済成功
              reservation.update!(
                payment_status: "completed",
                status: "confirmed"
              )

              # 成功レスポンス
              {
                success: true,
                reservation: reservation,
                payment_id: "pay_#{SecureRandom.hex(10)}",
                processed_at: Time.current
              }
            else
              # 決済失敗
              reservation.update!(payment_status: "failed")

              # 失敗レスポンス
              {
                success: false,
                error: "決済処理に失敗しました",
                error_code: "payment_failed"
              }
            end
          end

          def self.refund_payment(reservation_id:)
            reservation = Reservation.find_by(id: reservation_id)

            # 基本的なバリデーション
            return {success: false, error: "予約が見つかりません"} unless reservation
            return {success: false, error: "支払いが完了していない予約です"} unless reservation.payment_status == "completed"

            # 返金処理
            reservation.update!(
              payment_status: "refunded",
              status: "cancelled"
            )

            # 成功レスポンス
            {
              success: true,
              reservation: reservation,
              refund_id: "ref_#{SecureRandom.hex(10)}",
              refunded_at: Time.current
            }
          end
        end

        # モッククラスでPaymentServiceを上書き
        Object.const_set(:PaymentService, payment_service_mock)
      end

      # モック解除
      def teardown
        # バックアップがあれば元に戻す
        if Object.const_defined?(:OriginalPaymentService)
          Object.const_set(:PaymentService, OriginalPaymentService)
          Object.send(:remove_const, :OriginalPaymentService)
        end
      end
    end
  end
end
