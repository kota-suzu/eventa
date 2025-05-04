# frozen_string_literal: true

# PaymentServiceのモッククラス
# テスト時に決済サービスをモック化するためのクラス
module Mocks
  # 結果を表す構造体
  MockResult = Struct.new(:success?, :transaction_id, :error_message, keyword_init: true)

  # モック用のクラスを事前に定義
  class MockPaymentService
    attr_reader :reservation, :payment_params

    def initialize(reservation, payment_params)
      @reservation = reservation
      @payment_params = payment_params
    end

    def process
      method_name = "process_#{payment_params[:method]}"

      if respond_to?(method_name, true)
        send(method_name)
      else
        MockResult.new(success?: false, error_message: "無効な支払い方法です")
      end
    rescue => e
      MockResult.new(success?: false, error_message: e.message)
    end

    private

    def process_credit_card
      # テスト用の支払い成功/失敗シミュレーション
      if payment_params[:token] == "tok_visa"
        # 決済成功
        transaction_id = "ch_#{SecureRandom.hex(10)}"

        # トランザクションを使わず直接更新（テスト環境の安定性のため）
        # 明示的にstringとして設定することで、enumの問題を回避
        @reservation.status = "confirmed"
        @reservation.paid_at = Time.current
        @reservation.transaction_id = transaction_id
        @reservation.save!

        # 確実にデータベースから再取得
        @reservation.reload

        MockResult.new(success?: true, transaction_id: transaction_id)
      else
        # 決済失敗
        @reservation.status = "payment_failed"
        @reservation.save!

        # 確実にデータベースから再取得
        @reservation.reload

        MockResult.new(success?: false, error_message: "カードが拒否されました")
      end
    end

    def process_bank_transfer
      # 銀行振込のシミュレーション
      transaction_id = "bank_transfer_#{SecureRandom.hex(8)}"
      MockResult.new(success?: true, transaction_id: transaction_id)
    end

    def process_convenience_store
      # コンビニ決済のシミュレーション
      transaction_id = "cvs_#{SecureRandom.hex(8)}"
      MockResult.new(success?: true, transaction_id: transaction_id)
    end
  end

  class PaymentService
    class << self
      # テスト環境用のモック設定
      def setup
        # 本番のPaymentServiceクラスをバックアップ
        if Object.const_defined?(:PaymentService) && !Object.const_defined?(:OriginalPaymentService)
          Object.const_set(:OriginalPaymentService, PaymentService)
        end

        # 事前定義したモッククラスをPaymentServiceとして設定
        Object.const_set(:PaymentService, Mocks::MockPaymentService)
      end

      # モック解除
      def teardown
        # バックアップがあれば元に戻す
        if Object.const_defined?(:OriginalPaymentService)
          Object.const_set(:PaymentService, OriginalPaymentService)
          Object.send(:remove_const, :OriginalPaymentService)
        end
      end
    end
  end
end
