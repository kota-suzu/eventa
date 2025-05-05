# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReservationSerializer do
  let(:user) { create(:user) }
  let(:ticket) { create(:ticket) }
  let(:reservation) { create(:reservation, user: user, ticket: ticket, quantity: 2, total_price: 5000) }

  describe "シリアライズ" do
    subject { JSON.parse(described_class.new(reservation).serializable_hash.to_json) }

    it "予約の基本属性が含まれていること" do
      result = subject

      expect(result).to have_key("data")
      expect(result["data"]["id"]).to eq(reservation.id.to_s)
      expect(result["data"]["type"]).to eq("reservation")

      attributes = result["data"]["attributes"]
      expect(attributes["quantity"]).to eq(reservation.quantity)
      expect(attributes["total_price"]).to eq(reservation.total_price)
      expect(attributes["status"]).to eq(reservation.status)
    end

    it "ユーザーとチケットへの関連が含まれていること" do
      result = subject

      expect(result["data"]["relationships"]).to have_key("user")
      expect(result["data"]["relationships"]).to have_key("ticket")
      expect(result["data"]["relationships"]["user"]["data"]["id"]).to eq(user.id.to_s)
      expect(result["data"]["relationships"]["ticket"]["data"]["id"]).to eq(ticket.id.to_s)
    end
  end
end
