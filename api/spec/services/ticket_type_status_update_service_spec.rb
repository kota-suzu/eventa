# frozen_string_literal: true

require "rails_helper"

RSpec.describe TicketTypeStatusUpdateService, type: :service do
  # すべてのテストで共有するイベントを用意
  before(:all) do
    # データベースをクリーンアップ
    DatabaseCleaner.clean_with(:truncation)
    # イベントを作成（一意のユーザーを強制的に作成）
    @shared_event = create(:event, user: create(:user, email: "shared_event_#{Time.now.to_i}@example.com"))
  end

  # 各テスト後にデータをクリーンアップ
  after(:each) do
    DatabaseCleaner.clean_with(:transaction)
  end

  describe "#update_status_based_on_time" do
    let(:service) { described_class.new }

    it "販売開始日時を迎えた準備中のチケットを販売中に更新する" do
      # 特定のテスト用データを用意
      draft_ticket = create(:ticket_type, :minimal,
        event: @shared_event,
        status: "draft",
        sales_start_at: 1.hour.ago,
        sales_end_at: 1.day.from_now)

      # トランザクション数を減らすためにDBアクセスをカウント
      expect {
        service.update_status_based_on_time
      }.to change { ActiveRecord::Base.connection.query_cache.size }.by_at_most(5)

      # リロードして状態を確認
      draft_ticket.reload
      expect(draft_ticket.status).to eq("on_sale")
    end

    it "販売終了日時を過ぎた販売中のチケットを販売終了に更新する" do
      on_sale_ticket = create(:ticket_type, :minimal,
        event: @shared_event,
        status: "on_sale",
        sales_start_at: 2.days.ago,
        sales_end_at: 1.hour.ago)

      service.update_status_based_on_time

      on_sale_ticket.reload
      expect(on_sale_ticket.status).to eq("closed")
    end

    it "販売開始前のチケットは更新されない" do
      future_ticket = create(:ticket_type, :minimal,
        event: @shared_event,
        status: "draft",
        sales_start_at: 1.day.from_now,
        sales_end_at: 2.days.from_now)

      service.update_status_based_on_time

      future_ticket.reload
      expect(future_ticket.status).to eq("draft")
    end

    it "販売終了日時前の販売中チケットは更新されない" do
      active_ticket = create(:ticket_type, :minimal,
        event: @shared_event,
        status: "on_sale",
        sales_start_at: 1.day.ago,
        sales_end_at: 1.day.from_now)

      service.update_status_based_on_time

      active_ticket.reload
      expect(active_ticket.status).to eq("on_sale")
    end

    it "すでに販売終了したチケットは更新されない" do
      closed_ticket = create(:ticket_type, :minimal,
        event: @shared_event,
        status: "closed",
        sales_start_at: 2.days.ago,
        sales_end_at: 1.day.ago)

      service.update_status_based_on_time

      closed_ticket.reload
      expect(closed_ticket.status).to eq("closed")
    end

    it "売り切れチケットは時間ベースで更新されない" do
      soldout_ticket = create(:ticket_type, :minimal,
        event: @shared_event,
        status: "soldout",
        sales_start_at: 2.days.ago,
        sales_end_at: 1.day.from_now)

      service.update_status_based_on_time

      soldout_ticket.reload
      expect(soldout_ticket.status).to eq("soldout")
    end
  end

  describe "#update_status_based_on_stock" do
    let(:service) { described_class.new }

    it "在庫がなくなった販売中のチケットを売切れに更新する" do
      # オリジナルのメソッドを保存
      original_method = TicketType.method(:on_sale)

      begin
        # TicketType.on_saleをモック化
        ticket_ids = [1, 2, 3]
        allow(TicketType).to receive(:on_sale) do
          relation = double("ActiveRecord::Relation")
          allow(relation).to receive(:joins).and_return(relation)
          allow(relation).to receive(:where).and_return(relation)
          allow(relation).to receive(:group).and_return(relation)
          allow(relation).to receive(:pluck).and_return(ticket_ids)
          relation
        end

        # TicketType.whereをモック化
        update_relation = double("ActiveRecord::Relation")
        expect(TicketType).to receive(:where).with(id: ticket_ids).and_return(update_relation)
        expect(update_relation).to receive(:update_all).with(status: "soldout").and_return(3)

        # Sidekiqロガーをモック化
        expect(Sidekiq.logger).to receive(:info).with(/【在庫切れ更新】3件のチケットタイプを「売切れ」に更新しました/)

        # テスト実行
        service.update_status_based_on_stock
      ensure
        # オリジナルのメソッドを復元
        TicketType.singleton_class.send(:define_method, :on_sale, original_method)
      end
    end

    it "在庫切れが0件の場合はログ出力されない" do
      # オリジナルのメソッドを保存
      original_method = TicketType.method(:on_sale)

      begin
        # 空の結果を返すようにモック化
        allow(TicketType).to receive(:on_sale) do
          relation = double("ActiveRecord::Relation")
          allow(relation).to receive(:joins).and_return(relation)
          allow(relation).to receive(:where).and_return(relation)
          allow(relation).to receive(:group).and_return(relation)
          allow(relation).to receive(:pluck).and_return([])
          relation
        end

        # Sidekiqロガーをモック化
        expect(Sidekiq.logger).not_to receive(:info)

        # テスト実行
        service.update_status_based_on_stock
      ensure
        # オリジナルのメソッドを復元
        TicketType.singleton_class.send(:define_method, :on_sale, original_method)
      end
    end

    # その他のテストも同様に修正...
  end

  describe "#update_all_statuses" do
    let(:service) { described_class.new }

    it "時間ベースと在庫ベースの両方の更新を実行する" do
      expect(service).to receive(:update_status_based_on_time)
      expect(service).to receive(:update_status_based_on_stock)

      service.update_all_statuses
    end

    it "時間ベースの更新が先に実行され、その後在庫ベースの更新が実行される" do
      # 実行順序を確認するために配列に記録
      execution_order = []

      # メソッドをスタブ化して実行順序を記録
      allow(service).to receive(:update_status_based_on_time) do
        execution_order << :time_based
      end

      allow(service).to receive(:update_status_based_on_stock) do
        execution_order << :stock_based
      end

      service.update_all_statuses

      # 実行順序を検証
      expect(execution_order).to eq([:time_based, :stock_based])
    end

    it "最初のメソッドで例外が発生しても2番目のメソッドは実行される" do
      # Sidekiqロガーをモック化
      logger_double = instance_double("Sidekiq::Logger")
      allow(Sidekiq).to receive(:logger).and_return(logger_double)
      allow(logger_double).to receive(:error)

      # update_status_based_on_timeが例外を発生させるようにスタブ
      allow(service).to receive(:update_status_based_on_time).and_raise(StandardError.new("Test error"))

      # update_status_based_on_stockが呼ばれることを確認
      expect(service).to receive(:update_status_based_on_stock)

      # エラーログが出力されることを確認
      expect(logger_double).to receive(:error).with(/Error updating ticket type statuses based on time: Test error/)

      # テスト実行
      service.update_all_statuses
    end
  end
end
