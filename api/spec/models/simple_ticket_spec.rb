# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ticket, type: :model do
  it "has a valid factory" do
    # まずユーザーを作成
    user = User.create!(
      email: "test-user@example.com",
      name: "テストユーザー",
      password: "password123"
    )

    # 次にイベントを作成
    event = Event.create!(
      title: "テストイベント",
      start_at: 1.day.from_now,
      end_at: 2.days.from_now,
      venue: "テスト会場",
      capacity: 100,
      is_public: true,
      user: user
    )

    # チケットを作成 - 必ず event_id を設定
    ticket = Ticket.new(
      title: "テストチケット",
      event: event,  # 関連付けを設定
      price: 1000,
      quantity: 5,
      available_quantity: 5
    )
    expect(ticket).to be_valid
  end
end
