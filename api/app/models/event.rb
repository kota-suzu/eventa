# frozen_string_literal: true

class Event < ApplicationRecord
  belongs_to :user
  has_many :tickets, dependent: :destroy
  has_many :ticket_types, dependent: :destroy
  has_many :reservations, through: :tickets

  # 後方互換性のためのエイリアス
  alias_attribute :name, :title
  alias_attribute :start_date, :start_at
  alias_attribute :end_date, :end_at
  alias_attribute :location, :venue

  validates :title, presence: true, length: {maximum: 100}
  validates :description, presence: true
  validates :start_at, presence: true
  validates :end_at, presence: true
  validates :venue, presence: true
  validates :capacity, numericality: {greater_than: 0}
  validate :end_at_after_start_at
  validate :capacity_limit

  # TODO(!feature): イベントのタグ機能を追加
  # ユーザーがイベントを検索しやすくするために、タグ付け機能を実装
  # - Acts-As-Taggableを導入検討
  # - タグの自動提案機能

  # TODO(!performance): キャパシティに関する計算をキャッシュする
  # 現在、残席数の計算が毎回クエリを実行しているため、大量アクセス時にパフォーマンスが低下
  # - Redisでのキャッシュ対応
  # - カウンターキャッシュカラムの追加

  # OPTIMIZE: イベントの検索機能を高速化
  # 現在の単純なクエリから、Elasticsearchなどの検索エンジンを導入する

  scope :upcoming, -> { where("start_at >= ?", Date.current) }
  scope :past, -> { where("end_at < ?", Date.current) }

  # 販売中のチケットタイプを取得
  def on_sale_ticket_types
    ticket_types.on_sale
  end

  # 販売可能なチケットタイプを取得（時間的に有効なもの）
  def active_ticket_types
    ticket_types.active
  end

  def available_seats
    capacity - reservations.count
  end

  def available?
    available_seats > 0
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
