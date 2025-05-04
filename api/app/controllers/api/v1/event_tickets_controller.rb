# frozen_string_literal: true

module Api
  module V1
    class EventTicketsController < ApplicationController
      def index
        event = Event.find(params[:event_id])
        tickets = event.tickets
          .includes(:event) # N+1回避
          .where("available_quantity > 0")
          .page(params[:page]).per(20) # ページネーション

        render json: TicketSerializer.new(tickets).serializable_hash
      end
    end
  end
end
