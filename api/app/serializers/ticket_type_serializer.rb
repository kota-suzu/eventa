# frozen_string_literal: true

class TicketTypeSerializer
  include JSONAPI::Serializer

  attributes :id, :name, :description, :price, :quantity, :status, :created_at, :updated_at

  belongs_to :event
end
