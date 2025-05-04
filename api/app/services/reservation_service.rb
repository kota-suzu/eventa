# frozen_string_literal: true

class ReservationService
  class Error < StandardError; end

  def self.call!(user, params)
    new(user, params).execute!
  end

  def initialize(user, params)
    @user = user
    @params = params
    @ticket_id = params[:ticket_id]
    @quantity = params[:quantity].to_i
    @payment_method = params[:payment_method]
  end

  def execute!
    reservation = nil

    ApplicationRecord.transaction do
      ticket = find_and_lock_ticket
      validate_quantity!(ticket)
      update_ticket_quantity!(ticket)

      reservation = create_reservation!(ticket)
    end

    reservation
  end

  private

  def find_and_lock_ticket
    Ticket.lock.find(@ticket_id)
  rescue ActiveRecord::RecordNotFound
    raise Error, "チケットが見つかりません"
  end

  def validate_quantity!(ticket)
    raise Error, "在庫が不足しています（残り#{ticket.available_quantity}枚）" if @quantity > ticket.available_quantity
    raise Error, "数量は1以上を指定してください" if @quantity <= 0
  end

  def update_ticket_quantity!(ticket)
    # 楽観的ロックを使用して在庫を減らす
    ticket.with_lock do
      ticket.decrement!(:available_quantity, @quantity)
    end
  rescue ActiveRecord::StaleObjectError
    # 楽観的ロックの競合が発生した場合
    raise Error, "在庫の更新中に競合が発生しました。再試行してください"
  end

  def create_reservation!(ticket)
    @user.reservations.create!(
      ticket: ticket,
      quantity: @quantity,
      payment_method: @payment_method,
      status: "pending"
    )
  rescue ActiveRecord::RecordInvalid => e
    raise Error, e.message
  end
end
