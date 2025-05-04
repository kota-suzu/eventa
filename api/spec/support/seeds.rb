# frozen_string_literal: true

# テスト時のパフォーマンス向上のためのseedデータ作成サポート
module Seeds
  class << self
    def create_minimal_data
      return if @minimal_data_created

      # トランザクション内で実行してパフォーマンスを向上
      ApplicationRecord.transaction do
        create_test_user
        create_test_event
        create_test_ticket_types
      end

      @minimal_data_created = true
    end

    def create_test_user
      @test_user ||= User.find_or_create_by!(email: "test@example.com") do |user|
        user.name = "Test User"
        user.password = "password"
      end
    end

    def create_test_event
      @test_event ||= begin
        event = Event.find_or_initialize_by(title: "Test Event")
        unless event.persisted?
          event.description = "This is a test event"
          event.start_at = 1.day.from_now
          event.end_at = 2.days.from_now
          event.user = create_test_user
          event.venue = "Test Venue"  # 会場を追加
          event.capacity = 200        # 定員を追加
          event.save!
        end
        event
      end
    end

    def create_test_ticket_types
      return @test_ticket_types if @test_ticket_types

      @test_ticket_types = []

      # 販売中チケット
      @test_ticket_types << TicketType.find_or_create_by!(
        name: "Standard Ticket",
        event: @test_event
      ) do |tt|
        tt.price_cents = 1000
        tt.quantity = 100
        tt.sales_start_at = 1.hour.ago
        tt.sales_end_at = 1.day.from_now
        tt.status = "on_sale"
      end

      # 完売チケット
      @test_ticket_types << TicketType.find_or_create_by!(
        name: "VIP Ticket",
        event: @test_event
      ) do |tt|
        tt.price_cents = 5000
        tt.quantity = 10
        tt.sales_start_at = 1.day.ago
        tt.sales_end_at = 1.day.from_now
        tt.status = "soldout"
      end

      # 販売終了チケット
      @test_ticket_types << TicketType.find_or_create_by!(
        name: "Early Bird",
        event: @test_event
      ) do |tt|
        tt.price_cents = 800
        tt.quantity = 50
        tt.sales_start_at = 2.days.ago
        tt.sales_end_at = 1.hour.ago
        tt.status = "closed"
      end

      @test_ticket_types
    end

    def get_test_user
      create_test_user unless @test_user
      @test_user
    end

    def get_test_event
      create_test_event unless @test_event
      @test_event
    end

    def get_test_ticket_types
      create_test_ticket_types unless @test_ticket_types
      @test_ticket_types
    end
  end
end
