# frozen_string_literal: true

class TicketTypeStatusUpdateService
  def initialize
    # 将来的に依存関係を注入できるようにする
  end

  # チケットタイプのステータス更新を実行（時間ベースと在庫ベースの両方）
  def update_all_statuses
    begin
      update_status_based_on_time
    rescue => e
      Sidekiq.logger.error "Error updating ticket type statuses based on time: #{e.message}"
    end

    begin
      update_status_based_on_stock
    rescue => e
      Sidekiq.logger.error "Error updating ticket type statuses based on stock: #{e.message}"
    end
  end

  # 販売開始時間/終了時間に基づいたステータス更新
  def update_status_based_on_time
    # 販売開始時刻を過ぎた「準備中」チケットを「販売中」に更新
    current_time = Time.current
    draft_tickets_to_update = TicketType.where(status: "draft")
      .where("sales_start_at <= ?", current_time)

    if draft_tickets_to_update.exists?
      count = 0
      draft_tickets_to_update.in_batches do |batch|
        count += batch.update_all(status: "on_sale")
      end
      Sidekiq.logger.info "【販売開始更新】#{count}件のチケットタイプを「販売中」に更新しました" if count > 0
    end

    # 販売終了時刻を過ぎた「販売中」チケットを「終了」に更新
    on_sale_tickets_to_update = TicketType.where(status: "on_sale")
      .where("sales_end_at <= ?", current_time)

    if on_sale_tickets_to_update.exists?
      count = 0
      on_sale_tickets_to_update.in_batches do |batch|
        count += batch.update_all(status: "closed")
      end
      Sidekiq.logger.info "【販売終了更新】#{count}件のチケットタイプを「終了」に更新しました" if count > 0
    end
  end

  # 在庫状況に基づいたステータス更新
  def update_status_based_on_stock
    # 販売中かつ在庫がないチケットを取得
    # サブクエリでチケットタイプIDを取得し、それをもとに更新
    sold_out_ticket_ids = TicketType.on_sale
      .joins("LEFT JOIN tickets ON tickets.ticket_type_id = ticket_types.id")
      .where("ticket_types.quantity <= COALESCE(SUM(tickets.quantity), 0)")
      .group("ticket_types.id")
      .pluck("ticket_types.id")

    # 対象のチケットが存在する場合のみ更新処理を実行
    if sold_out_ticket_ids.present?
      count = TicketType.where(id: sold_out_ticket_ids).update_all(status: "soldout")
      Sidekiq.logger.info "【在庫切れ更新】#{count}件のチケットタイプを「売切れ」に更新しました" if count > 0
    end
  end
end
