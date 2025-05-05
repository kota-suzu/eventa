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
  end
end
