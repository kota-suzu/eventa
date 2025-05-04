# frozen_string_literal: true

require "rails_helper"

RSpec.describe "TicketReservations", type: :request do
  # すべてのテストを一時的にスキップ - APIコントローラーが完全に実装された後に有効化
  skip_until_api_implemented

  let(:user) { create(:user) }
  let(:event) { create(:event) }
  let(:ticket) { create(:ticket, event: event) }
  let(:auth_headers) { {"Authorization" => "Bearer #{generate_token_for(user)}"} }

  # トークン生成用のヘルパーメソッド
  def generate_token_for(user)
    # テスト用の簡易的なトークン生成
    # 実際の実装ではなく、モックトークンを返す
    "test_token_for_user_#{user.id}"
  end

  describe "POST /api/v1/ticket_reservations" do
    let(:valid_attributes) do
      {
        ticket_id: ticket.id,
        quantity: 2,
        payment_method: "credit_card"
      }
    end

    context "when user is authenticated" do
      it "creates a new reservation" do
        expect do
          post "/api/v1/ticket_reservations",
            params: valid_attributes,
            headers: auth_headers
        end.to change(Reservation, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)).to include("id", "status", "quantity")
      end

      it "sets the user_id from the JWT token" do
        post "/api/v1/ticket_reservations",
          params: valid_attributes,
          headers: auth_headers

        expect(response).to have_http_status(:created)
        expect(Reservation.last.user_id).to eq(user.id)
      end

      it "returns validation errors for invalid requests" do
        # 数量が不正な場合
        post "/api/v1/ticket_reservations",
          params: valid_attributes.merge(quantity: 0),
          headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)).to have_key("errors")
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        post "/api/v1/ticket_reservations", params: valid_attributes
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
