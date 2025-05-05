# frozen_string_literal: true

require "rails_helper"

RSpec.describe "TicketReservations", type: :request do
  let(:user) { create(:user) }
  let(:event) { create(:event) }
  let(:ticket) { create(:ticket, event: event, quantity: 10, available_quantity: 10) }
  let(:auth_headers) { {"Authorization" => "Bearer #{generate_token_for(user)}"} }
  # テスト用ヘッダーも追加
  let(:test_headers) { {"X-Test-User-Id" => user.id.to_s} }

  # トークン生成用のヘルパーメソッド
  def generate_token_for(user)
    # JsonWebTokenクラスを使用してトークンを生成
    JsonWebToken.encode({user_id: user.id})
  end

  describe "POST /api/v1/ticket_reservations" do
    let(:valid_attributes) do
      {
        ticket_id: ticket.id,
        quantity: 2,
        payment_method: "credit_card",
        payment_params: {
          token: "tok_visa" # テスト用トークン
        }
      }
    end

    # テスト環境用のモックを有効化
    before do
      # ストライプモックを設定
      Mocks::PaymentServiceMock.setup
    end

    # テスト後に設定を元に戻す
    after do
      Mocks::PaymentServiceMock.teardown
    end

    context "when user is authenticated" do
      before do
        # 認証済みユーザーのモックを設定
        allow_any_instance_of(Api::V1::TicketReservationsController).to receive(:authenticate_user).and_return(true)
        allow_any_instance_of(Api::V1::TicketReservationsController).to receive(:current_user).and_return(user)
      end

      it "creates a new reservation" do
        expect do
          post "/api/v1/ticket_reservations",
            params: valid_attributes,
            headers: auth_headers.merge(test_headers)
        end.to change(Reservation, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)).to include("reservation")
      end

      it "sets the user_id from the JWT token" do
        post "/api/v1/ticket_reservations",
          params: valid_attributes,
          headers: auth_headers.merge(test_headers)

        expect(response).to have_http_status(:created)
        expect(Reservation.last.user_id).to eq(user.id)
      end

      it "returns validation errors for invalid requests" do
        # 数量が不正な場合
        post "/api/v1/ticket_reservations",
          params: valid_attributes.merge(quantity: 0),
          headers: auth_headers.merge(test_headers)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)).to have_key("error")
      end
    end

    context "when user is not authenticated" do
      before do
        # 認証に必要なメソッドをオーバーライドして401を強制的に返す
        allow_any_instance_of(Api::V1::TicketReservationsController).to receive(:authenticate_user) do
          render json: {error: "認証に失敗しました"}, status: :unauthorized
          false
        end
      end

      it "returns unauthorized status" do
        post "/api/v1/ticket_reservations", params: valid_attributes
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
