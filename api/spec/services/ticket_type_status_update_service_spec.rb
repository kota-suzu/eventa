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
      # 販売中で在庫0のチケットを用意
      on_sale_ticket = create(:ticket_type, :minimal,
        event: @shared_event,
        status: "on_sale",
        quantity: 10,
        sales_start_at: 1.day.ago,
        sales_end_at: 1.day.from_now)

      # 明示的にイベントを設定し、ユーザー作成の連鎖を避ける
      create(:ticket, ticket_type: on_sale_ticket, event: @shared_event, quantity: 10)

      # 確認
      expect(on_sale_ticket.remaining_quantity).to eq(0)

      service.update_status_based_on_stock

      on_sale_ticket.reload
      expect(on_sale_ticket.status).to eq("soldout")
    end

    it "在庫があるチケットは更新しない" do
      on_sale_ticket = create(:ticket_type, :minimal,
        event: @shared_event,
        status: "on_sale",
        quantity: 10,
        sales_start_at: 1.day.ago,
        sales_end_at: 1.day.from_now)

      # 明示的にイベントを設定し、ユーザー作成の連鎖を避ける
      create(:ticket, ticket_type: on_sale_ticket, event: @shared_event, quantity: 5)

      # 確認
      expect(on_sale_ticket.remaining_quantity).to eq(5)

      service.update_status_based_on_stock

      on_sale_ticket.reload
      expect(on_sale_ticket.status).to eq("on_sale")
    end

    it "販売中ではないチケットは在庫に関わらず更新しない" do
      # 準備中チケット
      draft_ticket = create(:ticket_type, :minimal,
        event: @shared_event,
        status: "draft",
        quantity: 10,
        sales_start_at: 1.day.from_now,
        sales_end_at: 2.days.from_now)

      create(:ticket, ticket_type: draft_ticket, event: @shared_event, quantity: 10)
      expect(draft_ticket.remaining_quantity).to eq(0)

      service.update_status_based_on_stock

      draft_ticket.reload
      expect(draft_ticket.status).to eq("draft") # 在庫がなくても更新されない

      # 販売終了チケット
      closed_ticket = create(:ticket_type, :minimal,
        event: @shared_event,
        status: "closed",
        quantity: 10,
        sales_start_at: 2.days.ago,
        sales_end_at: 1.day.ago)

      create(:ticket, ticket_type: closed_ticket, event: @shared_event, quantity: 10)
      expect(closed_ticket.remaining_quantity).to eq(0)

      service.update_status_based_on_stock

      closed_ticket.reload
      expect(closed_ticket.status).to eq("closed") # 在庫がなくても更新されない
    end

    it "すでに売り切れ状態のチケットは更新しない" do
      soldout_ticket = create(:ticket_type, :minimal,
        event: @shared_event,
        status: "soldout",
        quantity: 10,
        sales_start_at: 1.day.ago,
        sales_end_at: 1.day.from_now)

      service.update_status_based_on_stock

      soldout_ticket.reload
      expect(soldout_ticket.status).to eq("soldout")
    end
  end

  describe "#update_all_statuses" do
    let(:service) { described_class.new }

    it "時間ベースと在庫ベースの両方の更新を実行する" do
      expect(service).to receive(:update_status_based_on_time)
      expect(service).to receive(:update_status_based_on_stock)

      service.update_all_statuses
    end
  end
end
