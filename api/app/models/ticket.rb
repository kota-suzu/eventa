# frozen_string_literal: true

class Ticket < ApplicationRecord
  belongs_to :event
  belongs_to :ticket_type, optional: true
  has_many :reservations, dependent: :restrict_with_exception

  validates :title, presence: true, length: {maximum: 100}
  validates :event_id, presence: true
  validates :price, numericality: {greater_than_or_equal_to: 0}
  validates :quantity, numericality: {greater_than_or_equal_to: 1}
  validates :available_quantity, numericality: {
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: ->(ticket) { ticket.quantity }
  }

  before_validation :set_default_available_quantity, on: :create
  before_validation :set_from_ticket_type, if: -> { ticket_type.present? }

  class InsufficientQuantityError < StandardError; end

  def reserve(quantity)
    check_quantity_available(quantity)
    decrement_stock(quantity)
  end

  def self.reserve_with_lock(id, quantity)
    transaction do
      ticket = lock.find(id)
      ticket.reserve(quantity)
      ticket
    end
  end

  private

  def set_default_available_quantity
    self.available_quantity ||= quantity if quantity
  end

  def set_from_ticket_type
    self.title = ticket_type.name if title.blank?
    self.description = ticket_type.description if description.blank?
    self.price = ticket_type.price_cents / 100 if price.blank?
  end

  def check_quantity_available(quantity)
    unless quantity.is_a?(Integer) && quantity > 0
      raise ArgumentError, "数量は正の整数である必要があります"
    end

    if quantity > available_quantity
      raise InsufficientQuantityError, "在庫が不足しています（残り#{available_quantity}枚）"
    end
  end

  def decrement_stock(quantity)
    with_lock do
      decrement!(:available_quantity, quantity)
    end
  end
end
