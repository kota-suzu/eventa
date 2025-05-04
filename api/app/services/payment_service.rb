# frozen_string_literal: true

class PaymentService
  attr_reader :reservation, :payment_params

  Result = Struct.new(:success?, :transaction_id, :error_message, keyword_init: true)

  def initialize(reservation, payment_params)
    @reservation = reservation
    @payment_params = payment_params
  end

  def process
    method_name = "process_#{payment_params[:method]}"

    if respond_to?(method_name, true)
      send(method_name)
    else
      Result.new(success?: false, error_message: "無効な支払い方法です")
    end
  rescue => e
    Result.new(success?: false, error_message: e.message)
  end

  private

  def process_credit_card
    # idempotency_keyを使用して二重課金防止
    idempotency_key = "reservation_#{reservation.id}_#{SecureRandom.hex(8)}"

    begin
      ApplicationRecord.transaction do
        charge = Stripe::Charge.create({
          amount: payment_params[:amount],
          currency: "jpy",
          source: payment_params[:token],
          description: "Reservation ##{reservation.id}",
          idempotency_key: idempotency_key
        })

        if charge.status == "succeeded"
          reservation.status_confirmed!
          reservation.touch(:paid_at) # 支払日時を記録
          reservation.update!(transaction_id: charge.id)
          Result.new(success?: true, transaction_id: charge.id)
        else
          reservation.status_payment_failed!
          Result.new(success?: false, error_message: "支払い処理に失敗しました")
        end
      end
    rescue Stripe::CardError => e
      reservation.status_payment_failed!
      Result.new(success?: false, error_message: e.message)
    end
  end

  def process_bank_transfer
    # 銀行振込の場合は支払い確認待ちとして処理
    # 実際の振込確認は別プロセスで行う
    Result.new(success?: true, transaction_id: "bank_transfer_#{SecureRandom.hex(8)}")
  end

  def process_convenience_store
    # コンビニ決済の場合は支払い番号を発行
    # 実際の支払い確認は別プロセスで行う
    Result.new(success?: true, transaction_id: "cvs_#{SecureRandom.hex(8)}")
  end
end
