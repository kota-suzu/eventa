# frozen_string_literal: true

# テスト用のReservationServiceモック
module ReservationServiceMock
  # モック用のサービスモジュール
  module MockService
    def self.call!(user, params)
      ticket = Ticket.find(params[:ticket_id])

      # 在庫不足の場合はエラー
      if params[:quantity].to_i > ticket.available_quantity
        raise ReservationService::Error, "在庫不足です"
      end

      # 無効な支払い方法の場合はエラー
      if params[:payment_method] == "invalid_method"
        raise ReservationService::Error, "支払い方法が無効です"
      end

      # レコード作成
      Reservation.create!(
        user: user,
        ticket: ticket,
        quantity: params[:quantity].to_i,
        payment_method: params[:payment_method],
        status: "pending",
        total_price: ticket.price * params[:quantity].to_i
      )
    end
  end

  def self.setup
    # オリジナルのサービスを保存
    @original_service = ReservationService

    # RSpecのstub_constを使用する代わりに、一時的にクラスを入れ替え
    Object.send(:remove_const, :ReservationService) if Object.const_defined?(:ReservationService)
    Object.const_set(:ReservationService, MockService)
  end

  def self.teardown
    # オリジナルのサービスを復元
    if @original_service
      Object.send(:remove_const, :ReservationService) if Object.const_defined?(:ReservationService)
      Object.const_set(:ReservationService, @original_service)
      @original_service = nil
    end
  end
end
