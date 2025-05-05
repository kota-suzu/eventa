# frozen_string_literal: true

# ReservationServiceのモッククラス
# テスト時にチケット予約サービスをモック化するためのクラス
module Mocks
  class ReservationServiceMock
    class Error < StandardError; end

    VALID_PAYMENT_METHODS = %w[credit_card bank_transfer convenience_store].freeze

    # デフォルトでは自動的にモック化されないようにする
    @already_mocked = false

    class << self
      attr_accessor :already_mocked

      def setup
        # すでにモック化されていれば何もしない
        return if @already_mocked

        # 実際のクラスを退避（定数が定義されていなければ何もしない）
        if Object.const_defined?(:ReservationService)
          @original_reservation_service = ReservationService

          # モックに差し替え
          Object.send(:remove_const, :ReservationService)
          Object.const_set(:ReservationService, Mocks::ReservationServiceMock)
          @already_mocked = true
          puts "[TEST SETUP] ReservationService has been mocked with Mocks::ReservationServiceMock"
        end
      end

      def teardown
        # モック化されていなければ何もしない
        return unless @already_mocked

        # 元のクラスに戻す
        if Object.const_defined?(:ReservationService)
          Object.send(:remove_const, :ReservationService)
          Object.const_set(:ReservationService, @original_reservation_service)
          @already_mocked = false
          puts "[TEST TEARDOWN] ReservationService has been restored to original implementation"
        end
      end

      def call!(user, params)
        new(user, params).call!
      end
    end

    def initialize(user, params)
      @user = user
      @params = params
      @ticket_id = params[:ticket_id]
      @quantity = params[:quantity].to_i
      @payment_method = params[:payment_method]
    end

    def call!
      # payment_methodのバリデーション追加
      validate_payment_method!

      # 以前の実装と同様のバリデーション
      ticket = find_ticket
      validate_quantity!(ticket)

      # モックとして予約を作成
      create_reservation(ticket)
    end

    private

    def validate_payment_method!
      if @payment_method.nil? || @payment_method.empty?
        raise Error, "支払い方法は必須です"
      end

      unless VALID_PAYMENT_METHODS.include?(@payment_method)
        raise Error, "無効な支払い方法です: #{@payment_method}"
      end
    end

    def find_ticket
      ticket = Ticket.find_by(id: @ticket_id)
      raise Error, "チケットが見つかりません" unless ticket
      ticket
    end

    def validate_quantity!(ticket)
      raise Error, "在庫が不足しています（残り#{ticket.available_quantity}枚）" if @quantity > ticket.available_quantity
      raise Error, "数量は1以上を指定してください" if @quantity <= 0
    end

    def create_reservation(ticket)
      reservation = @user.reservations.new(
        ticket: ticket,
        quantity: @quantity,
        payment_method: @payment_method,
        status: "pending"
      )

      # 実際に保存せずに検証のみを行う
      unless reservation.valid?
        raise ActiveRecord::RecordInvalid.new(reservation)
      end

      # 在庫を減らす（テスト用に実際のDBに反映）
      ticket.with_lock do
        ticket.decrement!(:available_quantity, @quantity)
      end

      # モック環境では実際に作成する
      reservation.save!
      reservation
    rescue ActiveRecord::RecordInvalid => e
      raise Error, e.message
    end
  end
end
