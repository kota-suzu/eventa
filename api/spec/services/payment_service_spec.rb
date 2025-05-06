# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentService do
  # テスト開始前にモックを確実に有効化
  before(:each) do
    # モックが設定されていることを確認
    Mocks::PaymentServiceMock.setup
  end

  # テスト後にモックを解除
  after(:each) do
    Mocks::PaymentServiceMock.teardown
  end

  let(:user) { create(:user) }

  # ← モック化はsupport/mocks/payment_service_mock.rbのRSpecフックに任せるため、個別の設定は削除

  describe "#process" do
    context "クレジットカード決済" do
      let(:payment_params) do
        {
          method: "credit_card",
          token: "tok_visa",
          amount: 2000
        }
      end

      it "決済が成功する" do
        # 各テストで新しい予約を作成
        reservation = create(:reservation, user: user, total_price: 2000, status: "pending")

        service = PaymentService.new(reservation, payment_params)
        result = service.process

        # 成功したことを確認（実装またはモッククラスに依らず動作するよう柔軟に）
        expect(result.success?).to be true
        expect(result.transaction_id).to match(/^ch_/)

        # 予約を再読み込み
        reservation.reload

        # 文字列で返されるstatus_before_type_castを整数に変換してから比較
        expect(reservation.status_before_type_cast.to_i).to eq(Reservation.statuses[:confirmed])
      end

      it "決済が失敗する場合" do
        # 各テストで新しい予約を作成
        reservation = create(:reservation, user: user, total_price: 2000, status: "pending")

        # 失敗するトークンに変更
        failed_params = payment_params.merge(token: "tok_fail")

        service = PaymentService.new(reservation, failed_params)
        result = service.process

        # 失敗したことを確認
        expect(result.success?).to be false
        expect(result.error_message).to eq("カードが拒否されました")

        # 予約を再読み込み
        reservation.reload

        # 文字列で返されるstatus_before_type_castを整数に変換してから比較
        expect(reservation.status_before_type_cast.to_i).to eq(Reservation.statuses[:payment_failed])
      end

      it "トークンが未指定の場合は決済が失敗する" do
        reservation = create(:reservation, user: user, total_price: 2000, status: "pending")
        
        # トークンなしのパラメータ
        no_token_params = payment_params.merge(token: nil)
        
        service = PaymentService.new(reservation, no_token_params)
        result = service.process
        
        expect(result.success?).to be false
        expect(result.error_message).to eq("カードが拒否されました")
      end
    end

    context "銀行振込決済" do
      let(:payment_params) do
        {
          method: "bank_transfer",
          amount: 2000
        }
      end

      it "支払い情報が生成される" do
        reservation = create(:reservation, user: user, total_price: 2000)
        service = PaymentService.new(reservation, payment_params)
        result = service.process

        # 型チェックではなく機能的なチェックに変更
        expect(result.success?).to be true
        expect(result.transaction_id).to include("bank_transfer_")
      end

      it "予約のトランザクションIDを更新する" do
        reservation = create(:reservation, user: user, total_price: 2000)
        service = PaymentService.new(reservation, payment_params)
        result = service.process

        reservation.reload
        expect(reservation.transaction_id).to include("bank_transfer_")
        expect(reservation.transaction_id).to eq(result.transaction_id)
      end
    end

    context "コンビニ決済" do
      let(:payment_params) do
        {
          method: "convenience_store",
          amount: 2000
        }
      end

      it "支払い情報が生成される" do
        reservation = create(:reservation, user: user, total_price: 2000)
        service = PaymentService.new(reservation, payment_params)
        result = service.process

        expect(result.success?).to be true
        expect(result.transaction_id).to include("cvs_")

        # 予約のトランザクションIDが更新されていることを確認
        reservation.reload
        expect(reservation.transaction_id).to include("cvs_")
      end

      it "異なるコンビニ支払い毎に異なるトランザクションIDを生成する" do
        reservation1 = create(:reservation, user: user, total_price: 2000)
        reservation2 = create(:reservation, user: user, total_price: 3000)
        
        service1 = PaymentService.new(reservation1, payment_params)
        service2 = PaymentService.new(reservation2, payment_params)
        
        result1 = service1.process
        result2 = service2.process
        
        expect(result1.transaction_id).not_to eq(result2.transaction_id)
        expect(result1.success?).to be true
        expect(result2.success?).to be true
      end
    end

    context "不正な支払い方法" do
      let(:payment_params) do
        {
          method: "invalid_method",
          amount: 2000
        }
      end

      it "エラーを返す" do
        reservation = create(:reservation, user: user, total_price: 2000)
        service = PaymentService.new(reservation, payment_params)
        result = service.process

        # 型チェックではなく機能的なチェックに変更
        expect(result.success?).to be false
        expect(result.error_message).to eq("無効な支払い方法です")
      end

      it "メソッドがnilの場合もInvalidMethodProcessorを使用する" do
        nil_method_params = payment_params.merge(method: nil)
        reservation = create(:reservation, user: user, total_price: 2000)
        
        service = PaymentService.new(reservation, nil_method_params)
        result = service.process
        
        expect(result.success?).to be false
        expect(result.error_message).to eq("無効な支払い方法です")
      end
    end

    context "例外処理" do
      let(:payment_params) do
        {
          method: "credit_card",
          token: "tok_visa",
          amount: 2000
        }
      end

      it "例外が発生した場合はエラー結果を返す" do
        reservation = create(:reservation, user: user, total_price: 2000, status: "pending")

        # 例外を発生させるメソッドを使用
        error_params = {
          method: "error_test", # 特殊な例外を発生させるメソッド
          amount: 2000
        }

        service = PaymentService.new(reservation, error_params)
        result = service.process

        expect(result.success?).to be false
        expect(result.error_message).to eq("テスト例外")
      end

      it "リザベーションの更新に失敗した場合もエラー結果を返す" do
        reservation = create(:reservation, user: user, total_price: 2000, status: "pending")
        
        # 予約オブジェクトをモックして更新時に例外を発生させる
        allow(reservation).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(reservation))
        
        service = PaymentService.new(reservation, payment_params)
        result = service.process
        
        expect(result.success?).to be false
        # エラーメッセージが"バリデーションに失敗しました: "で始まることを確認
        expect(result.error_message).to start_with("バリデーションに失敗しました")
      end
    end
  end

  describe "#processor_for" do
    it "クレジットカード決済のプロセッサーを返す" do
      reservation = create(:reservation, user: user)
      service = PaymentService.new(reservation, {method: "credit_card"})

      # privateメソッドを直接テスト
      processor = service.send(:processor_for, "credit_card")
      expect(processor).to be_an_instance_of(PaymentService::CreditCardProcessor)
    end

    it "銀行振込決済のプロセッサーを返す" do
      reservation = create(:reservation, user: user)
      service = PaymentService.new(reservation, {method: "bank_transfer"})

      processor = service.send(:processor_for, "bank_transfer")
      expect(processor).to be_an_instance_of(PaymentService::BankTransferProcessor)
    end

    it "コンビニ決済のプロセッサーを返す" do
      reservation = create(:reservation, user: user)
      service = PaymentService.new(reservation, {method: "convenience_store"})

      processor = service.send(:processor_for, "convenience_store")
      expect(processor).to be_an_instance_of(PaymentService::ConvenienceStoreProcessor)
    end

    it "無効な支払い方法の場合はInvalidMethodProcessorを返す" do
      reservation = create(:reservation, user: user)
      service = PaymentService.new(reservation, {method: "unknown"})

      processor = service.send(:processor_for, "unknown")
      expect(processor).to be_an_instance_of(PaymentService::InvalidMethodProcessor)
    end

    it "メソッドがnilの場合もInvalidMethodProcessorを返す" do
      reservation = create(:reservation, user: user)
      service = PaymentService.new(reservation, {method: nil})
      
      processor = service.send(:processor_for, nil)
      expect(processor).to be_an_instance_of(PaymentService::InvalidMethodProcessor)
    end

    it "メソッドが空文字の場合もInvalidMethodProcessorを返す" do
      reservation = create(:reservation, user: user)
      service = PaymentService.new(reservation, {method: ""})
      
      processor = service.send(:processor_for, "")
      expect(processor).to be_an_instance_of(PaymentService::InvalidMethodProcessor)
    end
  end

  describe "Result class" do
    it "成功結果を生成する" do
      result = PaymentService::Result.success("test_transaction_id")

      expect(result.success?).to be true
      expect(result.transaction_id).to eq("test_transaction_id")
      expect(result.error_message).to be_nil
    end

    it "エラー結果を生成する" do
      result = PaymentService::Result.error("テストエラー")

      expect(result.success?).to be false
      expect(result.transaction_id).to be_nil
      expect(result.error_message).to eq("テストエラー")
    end
  end

  describe "CreditCardProcessor" do
    it "トークンがnilの場合は失敗する" do
      reservation = create(:reservation, user: user)
      processor = PaymentService::CreditCardProcessor.new(
        reservation, 
        {token: nil}
      )
      
      result = processor.process
      expect(result.success?).to be false
    end
    
    it "トークンが空文字の場合は失敗する" do
      reservation = create(:reservation, user: user)
      processor = PaymentService::CreditCardProcessor.new(
        reservation, 
        {token: ""}
      )
      
      result = processor.process
      expect(result.success?).to be false
    end
    
    it "更新時のステータスと時刻が正しく設定される" do
      reservation = create(:reservation, user: user, status: "pending")
      processor = PaymentService::CreditCardProcessor.new(
        reservation, 
        {token: "tok_visa"}
      )
      
      expect(reservation).to receive(:update!).with(
        hash_including(
          status: :confirmed,
          paid_at: an_instance_of(ActiveSupport::TimeWithZone),
          transaction_id: a_string_matching(/^ch_/)
        )
      )
      
      processor.process
    end
  end
end
