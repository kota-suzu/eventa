# frozen_string_literal: true

# 決済処理を行うサービスクラス
class PaymentService
  attr_reader :reservation, :payment_params

  # 支払い処理サービスクラス
  # このサービスは決済処理を抽象化し、複数の決済プロバイダをサポートします

  # TODO(!feature!urgent): 支払い処理システムの完全実装
  # Stripeをメインの決済プロバイダとして完全統合し、
  # 決済処理、返金、サブスクリプション管理などの機能を実装。
  # エラーハンドリングとリトライロジックも強化。

  # TODO(!feature): 決済履歴管理機能
  # ユーザーごとの決済履歴を管理し、履歴表示、請求書発行、
  # 領収書ダウンロード機能などを実装。取引履歴の長期保存も対応。

  # TODO(!security): 決済セキュリティ強化
  # PCI DSS準拠のための対策を実装。カード情報の安全な取り扱い、
  # 不正検知システム、リスク評価による追加認証などを含む。

  # TODO(!feature): 返金処理システム
  # イベントのキャンセルやユーザーからの返金リクエストに対応する
  # 柔軟な返金処理システムを実装。部分返金や払い戻しポリシーの適用も可能に。

  # TODO(!feature): 複数決済方法のサポート
  # クレジットカード以外にも、銀行振込、PayPal、Apple Pay、
  # Google Pay、コンビニ決済などの多様な決済方法をサポート。

  def initialize(reservation, payment_params)
    @reservation = reservation
    @payment_params = payment_params
  end

  def process
    # 支払い方法に応じた処理を行う
    processor = processor_for(payment_params[:method])
    processor.process
  rescue => e
    # エラー時は失敗結果を返す
    Result.error(e.message)
  end

  private

  def processor_for(method)
    case method
    when "credit_card"
      CreditCardProcessor.new(reservation, payment_params)
    when "bank_transfer"
      BankTransferProcessor.new(reservation, payment_params)
    when "convenience_store"
      ConvenienceStoreProcessor.new(reservation, payment_params)
    else
      InvalidMethodProcessor.new(reservation, payment_params)
    end
  end

  # 結果オブジェクト（Success/Failure パターン）
  class Result
    attr_reader :success, :transaction_id, :error_message

    def self.success(transaction_id)
      new(true, transaction_id, nil)
    end

    def self.error(message)
      new(false, nil, message)
    end

    def initialize(success, transaction_id, error_message)
      @success = success
      @transaction_id = transaction_id
      @error_message = error_message
    end

    def success?
      @success
    end
  end

  # 基底プロセッサークラス
  class BaseProcessor
    attr_reader :reservation, :payment_params

    def initialize(reservation, payment_params)
      @reservation = reservation
      @payment_params = payment_params
    end

    def process
      raise NotImplementedError, "#{self.class} must implement #process"
    end
  end

  # クレジットカード処理クラス
  class CreditCardProcessor < BaseProcessor
    def process
      if payment_params[:token] == "tok_visa"
        process_successful_payment
      else
        process_failed_payment
      end
    end

    private

    def process_successful_payment
      transaction_id = "ch_#{SecureRandom.hex(10)}"

      reservation.update!(
        status: :confirmed,
        paid_at: Time.current,
        transaction_id: transaction_id
      )

      Result.success(transaction_id)
    end

    def process_failed_payment
      reservation.update!(status: :payment_failed)
      Result.error("カードが拒否されました")
    end
  end

  # 銀行振込処理クラス
  class BankTransferProcessor < BaseProcessor
    def process
      transaction_id = "bank_transfer_#{SecureRandom.hex(8)}"
      reservation.update!(transaction_id: transaction_id)
      Result.success(transaction_id)
    end
  end

  # コンビニ決済処理クラス
  class ConvenienceStoreProcessor < BaseProcessor
    def process
      transaction_id = "cvs_#{SecureRandom.hex(8)}"
      reservation.update!(transaction_id: transaction_id)
      Result.success(transaction_id)
    end
  end

  # 無効な支払い方法処理クラス
  class InvalidMethodProcessor < BaseProcessor
    def process
      Result.error("無効な支払い方法です")
    end
  end
end
