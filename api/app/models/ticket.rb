# frozen_string_literal: true

class Ticket < ApplicationRecord
  belongs_to :event
  has_many :reservations, dependent: :restrict_with_exception

  validates :title, presence: true
  validates :event_id, presence: true
  validates :price, numericality: {greater_than_or_equal_to: 0}
  validates :quantity, numericality: {greater_than_or_equal_to: 1}
  validates :available_quantity, numericality: {
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: ->(ticket) { ticket.quantity }
  }

  before_validation :set_default_available_quantity, on: :create

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

  def check_quantity_available(quantity)
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
