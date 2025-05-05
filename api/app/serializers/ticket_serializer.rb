# frozen_string_literal: true

class TicketSerializer
  include JSONAPI::Serializer

  attributes :id, :title, :description, :price, :quantity, :available_quantity, :created_at, :updated_at

  belongs_to :ticket_type
  belongs_to :event
end
