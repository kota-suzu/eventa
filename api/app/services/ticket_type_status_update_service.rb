# frozen_string_literal: true

class TicketTypeStatusUpdateService
  def initialize
    # 必要に応じて依存関係を注入
  end

  def update_status_based_on_time
    # 販売開始日時を迎えた「準備中」のチケットを「販売中」に更新
    now = Time.current

    draft_updated = 0
    TicketType.where(status: "draft")
      .where("sales_start_at <= ?", now)
      .in_batches(of: 100) do |relation|
      updated = relation.update_all(status: "on_sale")
      draft_updated += updated
    end
    Sidekiq.logger.info "【販売開始更新】#{draft_updated}件のチケットタイプを「販売中」に更新しました" if draft_updated > 0

    # 販売終了日時を過ぎた「販売中」のチケットを「終了」に更新
    closed_updated = 0
    TicketType.where(status: "on_sale")
      .where("sales_end_at < ?", now)
      .in_batches(of: 100) do |relation|
      updated = relation.update_all(status: "closed")
      closed_updated += updated
    end
    Sidekiq.logger.info "【販売終了更新】#{closed_updated}件のチケットタイプを「終了」に更新しました" if closed_updated > 0
  end

  def update_status_based_on_stock
    # 残りの在庫が0になった「販売中」のチケットを「売切れ」に更新
    # 効率的なサブクエリを使用して在庫切れの対象を特定
    sold_out_updated = 0

    # サブクエリを使用して効率的に在庫切れチケットタイプを検索し一括更新
    soldout_ids = TicketType.on_sale
      .joins("LEFT JOIN (SELECT ticket_type_id, SUM(quantity) as sold FROM tickets GROUP BY ticket_type_id) as t " \
                         "ON t.ticket_type_id = ticket_types.id")
      .where("ticket_types.quantity <= COALESCE(t.sold, 0)")
      .pluck(:id)

    if soldout_ids.present?
      updated = TicketType.where(id: soldout_ids).update_all(status: "soldout")
      sold_out_updated += updated
    end

    Sidekiq.logger.info "【在庫切れ更新】#{sold_out_updated}件のチケットタイプを「売切れ」に更新しました" if sold_out_updated > 0
  end
end
