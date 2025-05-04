# frozen_string_literal: true

# ReservationServiceのモッククラス
# テスト時にチケット予約サービスをモック化するためのクラス
module Mocks
  class ReservationService
    class << self
      # テスト環境用のモック設定
      def setup
        # 本番のReservationServiceクラスをバックアップ
        if Object.const_defined?(:ReservationService) && !Object.const_defined?(:OriginalReservationService)
          Object.const_set(:OriginalReservationService, ReservationService)
        end

        # モッククラスの定義
        reservation_service_mock = Class.new do
          def self.reserve(ticket_id:, user_id:, quantity:, payment_method:, card_token: nil)
            ticket = Ticket.find_by(id: ticket_id)

            # 基本的なバリデーション
            return {success: false, error: "チケットが見つかりません"} unless ticket
            return {success: false, error: "在庫不足です"} if ticket.available_quantity < quantity
            return {success: false, error: "不正な数量です"} if quantity <= 0
            return {success: false, error: "不正な支払い方法です"} unless %w[credit_card bank_transfer].include?(payment_method)

            # 予約作成
            reservation = Reservation.create!(
              ticket_id: ticket_id,
              user_id: user_id,
              quantity: quantity,
              status: "pending",
              payment_method: payment_method,
              payment_status: "pending",
              price_at_reservation: ticket.price,
              total_price: ticket.price * quantity
            )

            # 利用可能数を減らす
            ticket.update!(available_quantity: ticket.available_quantity - quantity)

            # 成功ケースでは作成された予約を返す
            {success: true, reservation: reservation}
          end
        end

        # モッククラスでReservationServiceを上書き
        Object.const_set(:ReservationService, reservation_service_mock)
      end

      # モック解除
      def teardown
        # バックアップがあれば元に戻す
        if Object.const_defined?(:OriginalReservationService)
          Object.const_set(:ReservationService, OriginalReservationService)
          Object.send(:remove_const, :OriginalReservationService)
        end
      end
    end
  end
end
