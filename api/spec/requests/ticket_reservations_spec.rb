# frozen_string_literal: true

require "rails_helper"

RSpec.describe "TicketReservations", type: :request do
  let(:user) { create(:user) }
  let(:event) { create(:event) }
  let!(:ticket) { create(:ticket, event: event, quantity: 10, price: 1000, available_quantity: 10) }
  let(:valid_params) do
    {
      ticket_id: ticket.id,
      quantity: 2,
      payment_method: "credit_card",
      card_token: "tok_visa"
    }
  end

  describe "POST /api/v1/ticket_reservations" do
    context "認証済みユーザー" do
      before do
        # 認証ヘッダーを設定
        post "/api/v1/auth/login", params: {email: user.email, password: "password"}
        @token = JSON.parse(response.body)["token"]
      end

      it "チケット予約が成功する" do
        expect {
          post "/api/v1/ticket_reservations",
            params: valid_params,
            headers: {"Authorization" => "Bearer #{@token}"}
        }.to change(Reservation, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["reservation"]["status"]).to eq("pending")
        expect(json["reservation"]["total_price"]).to eq(2000) # 1000円 x 2枚
      end

      it "在庫不足の場合は予約が失敗する" do
        params = valid_params.merge(quantity: 11) # 在庫は10枚

        post "/api/v1/ticket_reservations",
          params: params,
          headers: {"Authorization" => "Bearer #{@token}"}

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["error"]).to include("在庫不足")
      end

      it "支払い方法が不正な場合は予約が失敗する" do
        params = valid_params.merge(payment_method: "invalid_method")

        post "/api/v1/ticket_reservations",
          params: params,
          headers: {"Authorization" => "Bearer #{@token}"}

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["error"]).to include("支払い方法")
      end
    end

    context "未認証ユーザー" do
      it "認証エラーを返す" do
        post "/api/v1/ticket_reservations", params: valid_params
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
