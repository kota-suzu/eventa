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
    current_time = Time.current

    # 販売開始処理
    update_drafts_to_on_sale(current_time)

    # 販売終了処理
    update_on_sale_to_closed(current_time)
  end

  # 準備中から販売中への更新
  def update_drafts_to_on_sale(current_time)
    draft_tickets_to_update = find_draft_tickets_to_update(current_time)

    if draft_tickets_to_update.exists?
      count = update_tickets_status(draft_tickets_to_update, "on_sale")
      log_status_updates(count, "販売開始更新", "販売中") if count > 0
    end
  end

  # 販売中から販売終了への更新
  def update_on_sale_to_closed(current_time)
    on_sale_tickets_to_update = find_on_sale_tickets_to_update(current_time)

    if on_sale_tickets_to_update.exists?
      count = update_tickets_status(on_sale_tickets_to_update, "closed")
      log_status_updates(count, "販売終了更新", "終了") if count > 0
    end
  end

  # 販売開始対象のチケットを検索
  def find_draft_tickets_to_update(current_time)
    TicketType.where(status: "draft")
      .where("sales_start_at <= ?", current_time)
  end

  # 販売終了対象のチケットを検索
  def find_on_sale_tickets_to_update(current_time)
    TicketType.where(status: "on_sale")
      .where("sales_end_at <= ?", current_time)
  end

  # チケットのステータスを更新
  def update_tickets_status(tickets, new_status)
    count = 0
    tickets.in_batches do |batch|
      count += batch.update_all(status: new_status)
    end
    count
  end

  # ログ出力
  def log_status_updates(count, update_type, new_status)
    Sidekiq.logger.info "【#{update_type}】#{count}件のチケットタイプを「#{new_status}」に更新しました"
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
