# frozen_string_literal: true

class ReservationSerializer
  include JSONAPI::Serializer

  attributes :id, :quantity, :total_price, :status, :payment_method, :transaction_id, :paid_at, :created_at, :updated_at

  belongs_to :user
  belongs_to :ticket
end
