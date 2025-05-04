# frozen_string_literal: true

# テスト用のPaymentServiceモック
module PaymentServiceMock
  # オリジナルメソッドのモジュール置き換え用
  module ProcessOverride
    def process
      # PaymentService::Resultクラスを直接参照
      result_class = PaymentService::Result

      if payment_params[:method] == "credit_card"
        if payment_params[:token] == "tok_visa"
          # 成功
          transaction_id = "ch_#{SecureRandom.hex(8)}"
          reservation.update!(status: :confirmed, paid_at: Time.current, transaction_id: transaction_id)
          result_class.new(success?: true, transaction_id: transaction_id)
        else
          # 失敗
          reservation.update!(status: :payment_failed)
          result_class.new(success?: false, error_message: "カードが拒否されました")
        end
      elsif payment_params[:method] == "bank_transfer"
        # 銀行振込
        transaction_id = "bank_transfer_#{SecureRandom.hex(8)}"
        result_class.new(success?: true, transaction_id: transaction_id)
      else
        # 不正な方法
        result_class.new(success?: false, error_message: "無効な支払い方法です")
      end
    end
  end

  def self.setup
    @original_payment_service = PaymentService

    # プリペンドでメソッドをオーバーライド（より安全なパターン）
    PaymentService.prepend(ProcessOverride)
  end

  def self.teardown
    # モックを元に戻す処理は必要なし
    # prepend方式なのでクラスを再読み込みすれば自動的に元に戻る
    if @original_payment_service
      Object.send(:remove_const, :PaymentService) if Object.const_defined?(:PaymentService)
      Object.const_set(:PaymentService, @original_payment_service)
      @original_payment_service = nil
    end
  end
end
