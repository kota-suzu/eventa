# frozen_string_literal: true

class UpdateTicketTypeStatusJob < ApplicationJob
  queue_as :default

  def perform
    # 時間に基づく状態更新（期限切れ、販売開始など）
    update_status_based_on_time

    # 在庫状況に基づく状態更新（売切れなど）
    update_status_based_on_stock
  end

  private

  def update_status_based_on_time
    # 販売開始日時を迎えた「準備中」のチケットを「販売中」に更新
    draft_to_on_sale = TicketType.where(status: "draft")
                                .where("sales_start_at <= ?", Time.current)
    draft_to_on_sale.update_all(status: "on_sale") if draft_to_on_sale.exists?

    # 販売終了日時を過ぎた「販売中」のチケットを「終了」に更新
    on_sale_to_closed = TicketType.where(status: "on_sale")
                                 .where("sales_end_at < ?", Time.current)
    on_sale_to_closed.update_all(status: "closed") if on_sale_to_closed.exists?
  end

  def update_status_based_on_stock
    # 残りの在庫が0になった「販売中」のチケットを「売切れ」に更新
    # 注：残量が0かどうかの判定はモデル内のメソッドを使用するため一括更新できず
    TicketType.on_sale.find_each do |ticket_type|
      ticket_type.update(status: "soldout") if ticket_type.remaining_quantity <= 0
    end
  end
end 