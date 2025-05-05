# frozen_string_literal: true

# ReservationServiceのモッククラス
# テスト時にチケット予約サービスをモック化するためのクラス
module Mocks
  class ReservationServiceMock
    # Errorクラスを追加
    Error = Class.new(StandardError)

    class << self
      # テスト環境用のモック設定
      def setup
        # 既にモック化されていれば何もしない
        return if @already_mocked

        # 本番のReservationServiceクラスをバックアップ
        if Object.const_defined?(:ReservationService) && !Object.const_defined?(:OriginalReservationService)
          Object.const_set(:OriginalReservationService, ::ReservationService)
        end

        # モッククラスの定義
        reservation_service_mock = Class.new do
          # Errorクラスの定義
          const_set(:Error, ::Mocks::ReservationServiceMock::Error)

          def self.call!(user, params)
            ticket_id = params[:ticket_id]
            quantity = params[:quantity].to_i
            payment_method = params[:payment_method]

            ticket = Ticket.find_by(id: ticket_id)

            # バリデーション
            raise Error, "チケットが見つかりません" unless ticket
            raise Error, "在庫不足です" if ticket.available_quantity < quantity
            raise Error, "数量は1以上を指定してください" if quantity <= 0
            raise Error, "不正な支払い方法です" unless %w[credit_card bank_transfer].include?(payment_method)

            # 予約作成
            reservation = user.reservations.create!(
              ticket: ticket,
              quantity: quantity,
              status: "pending",
              payment_method: payment_method
            )

            # 利用可能数を減らす
            ticket.with_lock do
              ticket.decrement!(:available_quantity, quantity)
            end

            reservation
          end
        end

        # モッククラスでReservationServiceを上書き
        Object.send(:remove_const, :ReservationService) if Object.const_defined?(:ReservationService)
        Object.const_set(:ReservationService, reservation_service_mock)
        @already_mocked = true
      end

      # モック解除
      def teardown
        # バックアップがあれば元に戻す
        if Object.const_defined?(:OriginalReservationService) && @already_mocked
          Object.send(:remove_const, :ReservationService) if Object.const_defined?(:ReservationService)
          Object.const_set(:ReservationService, OriginalReservationService)
          Object.send(:remove_const, :OriginalReservationService)
          @already_mocked = false
        end
      end
    end
  end
end
