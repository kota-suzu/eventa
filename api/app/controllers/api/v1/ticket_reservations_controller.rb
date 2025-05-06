# frozen_string_literal: true

module Api
  module V1
    class TicketReservationsController < ApplicationController
      before_action :authenticate_request

      def create
        reservation = ReservationService.call!(
          current_user,
          reservation_params
        )

        render json: {
          reservation: {
            id: reservation.id,
            total_price: reservation.total_price,
            status: reservation.status
          },
          payment_url: payment_url_for(reservation)
        }, status: :created
      rescue ReservationService::Error => e
        render json: {error: e.message}, status: :unprocessable_entity
      end

      private

      def reservation_params
        params.permit(:ticket_id, :quantity, :payment_method)
      end

      def payment_url_for(reservation)
        # 環境設定から動的にフロントエンドURLを取得
        "#{Rails.application.config.frontend_origin}/reservations/#{reservation.id}/payment"
      end
    end
  end
end
