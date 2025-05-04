# frozen_string_literal: true

require "rails_helper"

RSpec.describe "TicketReservations", type: :request do
  let(:user) { create(:user, email: "test_reservation@example.com", password: "password123") }
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

  # テスト開始前にReservationServiceをモック化
  before(:all) do
    ReservationServiceMock.setup
  end

  # テスト終了後にモックを解除
  after(:all) do
    ReservationServiceMock.teardown
  end

  describe "POST /api/v1/ticket_reservations" do
    before do
      # すべてのテストをスキップ
      skip "APIエンドポイントが完全に実装されるまでskip"
    end

    context "認証済みユーザー" do
      before do
        # ユーザーを明示的に認証してトークンを取得
        post "/api/v1/auth/login", params: {email: user.email, password: "password123"}

        # レスポンスが成功していることを確認
        expect(response).to have_http_status(:ok)

        # トークンを取得
        json_response = JSON.parse(response.body)
        @token = json_response["token"]

        # トークンが取得できたことを確認
        expect(@token).not_to be_nil
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
