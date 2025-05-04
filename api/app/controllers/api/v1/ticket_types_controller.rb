# frozen_string_literal: true

module Api
  module V1
    class TicketTypesController < ApplicationController
      before_action :authenticate_user!
      before_action :set_event
      before_action :authorize_event_owner!
      before_action :set_ticket_type, only: [:show, :update, :destroy]

      # GET /api/v1/events/:event_id/ticket_types
      def index
        @ticket_types = @event.ticket_types
        render json: {
          data: @ticket_types.map { |tt| ticket_type_json(tt) },
          meta: { total: @ticket_types.count }
        }
      end

      # GET /api/v1/events/:event_id/ticket_types/:id
      def show
        render json: { data: ticket_type_json(@ticket_type) }
      end

      # POST /api/v1/events/:event_id/ticket_types
      def create
        @ticket_type = @event.ticket_types.build(ticket_type_params)

        if @ticket_type.save
          render json: { data: ticket_type_json(@ticket_type) }, status: :created
        else
          render json: { errors: @ticket_type.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PUT /api/v1/events/:event_id/ticket_types/:id
      def update
        if @ticket_type.update(ticket_type_params)
          render json: { data: ticket_type_json(@ticket_type) }
        else
          render json: { errors: @ticket_type.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/events/:event_id/ticket_types/:id
      def destroy
        if @ticket_type.tickets.exists?
          render json: { error: "既にチケットが発行されているため、削除できません" }, status: :unprocessable_entity
          return
        end

        @ticket_type.destroy
        head :no_content
      end

      private

      def set_event
        @event = Event.find(params[:event_id])
      end

      def set_ticket_type
        @ticket_type = @event.ticket_types.find(params[:id])
      end

      def authorize_event_owner!
        unless @event.user_id == current_user.id
          render json: { error: "このイベントの編集権限がありません" }, status: :forbidden
        end
      end

      def ticket_type_params
        params.require(:ticket_type).permit(
          :name, :description, :price_cents, :quantity,
          :sales_start_at, :sales_end_at, :status
        )
      end

      def ticket_type_json(ticket_type)
        {
          id: ticket_type.id,
          type: "ticket_types",
          attributes: {
            name: ticket_type.name,
            description: ticket_type.description,
            price_cents: ticket_type.price_cents,
            currency: ticket_type.currency,
            quantity: ticket_type.quantity,
            remaining: ticket_type.remaining_quantity,
            sales_start_at: ticket_type.sales_start_at,
            sales_end_at: ticket_type.sales_end_at,
            status: ticket_type.status
          }
        }
      end
    end
  end
end 