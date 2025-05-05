# frozen_string_literal: true

class EventSerializer
  include JSONAPI::Serializer

  attributes :id, :title, :description, :start_at, :end_at, :venue, :capacity, :status, :created_at, :updated_at

  # リレーションシップの定義
  belongs_to :user
  has_many :ticket_types
  has_many :tickets
end
