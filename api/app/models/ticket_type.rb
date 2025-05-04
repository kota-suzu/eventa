# frozen_string_literal: true

class TicketType < ApplicationRecord
  belongs_to :event
  has_many :tickets, dependent: :restrict_with_exception

  validates :name, presence: true, length: {maximum: 100}
  validates :price_cents, presence: true, numericality: {greater_than_or_equal_to: 0}
  validates :quantity, presence: true, numericality: {greater_than_or_equal_to: 0}
  validates :sales_start_at, presence: true
  validates :sales_end_at, presence: true
  validates :status, presence: true
  validate :sales_end_at_after_sales_start_at

  # デフォルト値
  attribute :currency, :string, default: "JPY"
  attribute :status, :string, default: "draft"

  enum status: {
    draft: "draft",       # 準備中
    on_sale: "on_sale",   # 販売中
    soldout: "soldout",   # 売切れ
    closed: "closed"      # 販売終了
  }

  # スコープ
  scope :on_sale, -> { where(status: "on_sale") }
  scope :active, -> { 
    on_sale.where("sales_start_at <= ? AND sales_end_at >= ?", Time.current, Time.current)
  }

  # メソッド
  def free?
    price_cents.zero?
  end

  def price
    price_cents / 100.0
  end

  def remaining_quantity
    if tickets.any?
      quantity - tickets.sum(:quantity)
    else
      quantity
    end
  end

  # 販売状況の自動チェック
  def update_status_based_on_time
    now = Time.current

    if status == "draft" && sales_start_at <= now
      update(status: "on_sale")
    elsif status == "on_sale" && sales_end_at < now
      update(status: "closed")
    end
  end

  # 在庫状況の自動チェック
  def update_status_based_on_stock
    if status == "on_sale" && remaining_quantity <= 0
      update(status: "soldout")
    end
  end

  private

  def sales_end_at_after_sales_start_at
    return if sales_end_at.blank? || sales_start_at.blank?

    if sales_end_at <= sales_start_at
      errors.add(:sales_end_at, "は販売開始日時より後に設定してください")
    end
  end
end 