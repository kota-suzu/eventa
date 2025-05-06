# frozen_string_literal: true

# PaymentServiceのモッククラス
# テスト時に決済サービスをモック化するためのクラス
module Mocks
  # 結果を表す構造体 - "?"で終わる名前は避ける
  MockResult = Struct.new(:successful, :transaction_id, :error_message, keyword_init: true)

  # success?メソッドを追加してsuccessfulの値を返す
  class MockResult
    def success?
      successful
    end
  end

  # モック用のクラスを事前に定義
  class MockPaymentService
    attr_reader :reservation, :payment_params

    # プロセッサークラスを定義
    class CreditCardProcessor
      def initialize(reservation, params)
        @reservation = reservation
        @params = params
      end

      def process
        if @params[:token] == "tok_visa"
          transaction_id = "ch_#{SecureRandom.hex(10)}"
          @reservation.update!(status: :confirmed, transaction_id: transaction_id, paid_at: Time.current)
          MockPaymentService::Result.success(transaction_id)
        else
          @reservation.update!(status: :payment_failed)
          MockPaymentService::Result.error("カードが拒否されました")
        end
      end
    end

    class BankTransferProcessor
      def initialize(reservation, params)
        @reservation = reservation
        @params = params
      end

      def process
        transaction_id = "bank_transfer_#{SecureRandom.hex(8)}"
        @reservation.update!(transaction_id: transaction_id)
        MockPaymentService::Result.success(transaction_id)
      end
    end

    class ConvenienceStoreProcessor
      def initialize(reservation, params)
        @reservation = reservation
        @params = params
      end

      def process
        transaction_id = "cvs_#{SecureRandom.hex(8)}"
        @reservation.update!(transaction_id: transaction_id)
        MockPaymentService::Result.success(transaction_id)
      end
    end

    class InvalidMethodProcessor
      def initialize(reservation, params)
        @reservation = reservation
        @params = params
      end

      def process
        MockPaymentService::Result.error("無効な支払い方法です")
      end
    end

    # Result クラスを追加
    class Result
      attr_reader :transaction_id, :error_message

      def initialize(success, transaction_id = nil, error_message = nil)
        @success = success
        @transaction_id = transaction_id
        @error_message = error_message
      end

      def success?
        @success
      end

      def self.success(transaction_id)
        new(true, transaction_id, nil)
      end

      def self.error(message)
        new(false, nil, message)
      end
    end

    def initialize(reservation, payment_params)
      @reservation = reservation
      @payment_params = payment_params
    end

    def process
      # テスト用に特定のメッセージで例外を投げるパラメータを検出
      if payment_params[:method] == "error_test"
        raise StandardError, "テスト例外"
      end

      method_name = "process_#{payment_params[:method]}"

      if respond_to?(method_name, true)
        send(method_name)
      else
        MockResult.new(successful: false, error_message: "無効な支払い方法です")
      end
    rescue => e
      MockResult.new(successful: false, error_message: e.message)
    end

    # processor_for メソッドを追加
    def processor_for(method)
      case method
      when "credit_card"
        CreditCardProcessor.new(@reservation, @payment_params)
      when "bank_transfer"
        BankTransferProcessor.new(@reservation, @payment_params)
      when "convenience_store"
        ConvenienceStoreProcessor.new(@reservation, @payment_params)
      else
        InvalidMethodProcessor.new(@reservation, @payment_params)
      end
    end

    private

    def process_credit_card
      # テスト用の支払い成功/失敗シミュレーション
      if payment_params[:token] == "tok_visa"
        # 決済成功
        transaction_id = "ch_#{SecureRandom.hex(10)}"

        # ActiveRecordの標準メソッドを使用して更新（SQLインジェクション対策にもなる）
        reservation.update!(
          status: :confirmed,
          paid_at: Time.current,
          transaction_id: transaction_id
        )

        # 確実にリロード
        reservation.reload

        MockResult.new(successful: true, transaction_id: transaction_id)
      else
        # 決済失敗 - 標準メソッドを使用
        reservation.update!(status: :payment_failed)

        # 確実にリロード
        reservation.reload

        MockResult.new(successful: false, error_message: "カードが拒否されました")
      end
    end

    def process_bank_transfer
      # 銀行振込のシミュレーション
      transaction_id = "bank_transfer_#{SecureRandom.hex(8)}"

      # トランザクションIDを設定
      reservation.update!(transaction_id: transaction_id)

      MockResult.new(successful: true, transaction_id: transaction_id)
    end

    def process_convenience_store
      # コンビニ決済のシミュレーション
      transaction_id = "cvs_#{SecureRandom.hex(8)}"

      # トランザクションIDを設定
      reservation.update!(transaction_id: transaction_id)

      MockResult.new(successful: true, transaction_id: transaction_id)
    end
  end

  class PaymentServiceMock
    class << self
      # テスト環境用のモック設定
      def setup
        # 確実にモック化されるよう、状態に関わらず一度クリア
        teardown if defined?(::OriginalPaymentService)

        # 本番のPaymentServiceクラスをバックアップ
        if Object.const_defined?(:PaymentService)
          # 既にモック化されている場合は何もしない
          return if ::PaymentService == Mocks::MockPaymentService

          Object.const_set(:OriginalPaymentService, ::PaymentService)
        end

        # 事前定義したモッククラスをPaymentServiceとして設定
        Object.send(:remove_const, :PaymentService) if Object.const_defined?(:PaymentService)
        Object.const_set(:PaymentService, Mocks::MockPaymentService)
        @already_mocked = true

        puts "[TEST SETUP] PaymentService has been mocked with Mocks::MockPaymentService"
      end

      # モック解除
      def teardown
        # バックアップがあれば元に戻す
        if Object.const_defined?(:OriginalPaymentService)
          Object.send(:remove_const, :PaymentService) if Object.const_defined?(:PaymentService)
          Object.const_set(:PaymentService, ::OriginalPaymentService)
          Object.send(:remove_const, :OriginalPaymentService)
          @already_mocked = false
          puts "[TEST TEARDOWN] PaymentService has been restored to original implementation"
        end
      end
    end
  end
end
