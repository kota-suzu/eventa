# frozen_string_literal: true

class EventSerializer
  include JSONAPI::Serializer

  attributes :id, :title, :description, :start_at, :end_at, :venue, :capacity, :status, :created_at, :updated_at

  has_many :ticket_types
  belongs_to :user
  has_many :tickets
end
