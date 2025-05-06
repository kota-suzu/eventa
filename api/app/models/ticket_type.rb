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

  # Rails 8.0 での enum 構文
  enum :status, {
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

  # パフォーマンス向上のためのスコープ
  scope :with_ticket_counts, -> {
    left_joins(:tickets)
      .select("ticket_types.*, COALESCE(SUM(tickets.quantity), 0) as sold_count")
      .group("ticket_types.id")
  }

  # メソッド
  def free?
    price_cents.zero?
  end

  def price
    price_cents / 100.0
  end

  def remaining_quantity
    # メモ化されている場合は早期リターン
    return @remaining_quantity if defined?(@remaining_quantity)

    # 売り上げ数を計算
    @remaining_quantity = calculate_remaining_quantity
  end

  # 残りの数量を計算
  def calculate_remaining_quantity
    if respond_to?(:sold_count)
      calculate_from_sold_count
    else
      calculate_from_tickets_sum
    end
  end

  # sold_countを使用して残り数を計算
  def calculate_from_sold_count
    quantity - (sold_count || 0)
  end

  # ticketsのsumを使用して残り数を計算
  def calculate_from_tickets_sum
    sold = tickets.sum(:quantity) || 0
    quantity - sold
  end

  # カウントとイベントを一度に取得するクラスメソッド
  def self.with_remaining_quantities
    joins("LEFT JOIN (SELECT ticket_type_id, SUM(quantity) as total_sold FROM tickets GROUP BY ticket_type_id) as t ON t.ticket_type_id = ticket_types.id")
      .select("ticket_types.*, (ticket_types.quantity - COALESCE(t.total_sold, 0)) as remaining")
  end

  private

  def sales_end_at_after_sales_start_at
    return if dates_blank?
    validate_end_after_start
  end

  # 日付が空かどうかをチェック
  def dates_blank?
    sales_end_at.blank? || sales_start_at.blank?
  end

  # 終了日が開始日より後であることを検証
  def validate_end_after_start
    if sales_end_at <= sales_start_at
      errors.add(:sales_end_at, "は販売開始日時より後に設定してください")
    end
  end
end
