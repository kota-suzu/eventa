# frozen_string_literal: true

class Reservation < ApplicationRecord
  belongs_to :user
  belongs_to :ticket

  # enumを導入して可読性向上
  enum :status, {
    pending: 0,
    confirmed: 1,
    payment_failed: 2,
    cancelled: 3
  }

  enum :payment_method, {
    credit_card: 0,
    bank_transfer: 1,
    convenience_store: 2
  }

  validates :quantity, numericality: {greater_than: 0}
  validates :total_price, numericality: {greater_than_or_equal_to: 0}

  before_validation :set_total_price, on: :create

  private

  def set_total_price
    self.total_price = ticket.price * quantity if ticket && quantity
  end
end
