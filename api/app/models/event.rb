# frozen_string_literal: true

class Event < ApplicationRecord
  belongs_to :user
  has_many :tickets, dependent: :destroy
  has_many :ticket_types, dependent: :destroy
  has_many :reservations, through: :tickets

  validates :title, presence: true
  validates :start_at, presence: true
  validates :end_at, presence: true
  validates :venue, presence: true
  validates :capacity, numericality: {greater_than: 0}
  validate :end_at_after_start_at
  validate :capacity_limit

  # 販売中のチケットタイプを取得
  def on_sale_ticket_types
    ticket_types.on_sale
  end

  # 販売可能なチケットタイプを取得（時間的に有効なもの）
  def active_ticket_types
    ticket_types.active
  end

  private

  def end_at_after_start_at
    return if end_at.blank? || start_at.blank?

    if end_at <= start_at
      errors.add(:end_at, "は開始時間より後に設定してください")
    end
  end

  def capacity_limit
    return unless tickets.any?

    total_ticket_quantity = tickets.sum(:quantity)
    if total_ticket_quantity > capacity
      errors.add(:capacity, "を超える枚数のチケットが発行されています（チケット総数: #{total_ticket_quantity}枚）")
    end
  end
end
