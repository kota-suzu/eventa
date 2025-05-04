# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Auth", type: :request do
  # すべてのテストを一時的にスキップ - APIコントローラーが完全に実装された後に有効化
  # 条件を満たしたので実行するためにコメントアウト
  # skip_until_api_implemented

  # 既にコントローラーアクションが実装されているので不要
  # skip_until_controller_action_implemented("Api::V1::AuthsController", "register")
  # skip_until_controller_action_implemented("Api::V1::AuthsController", "login")

  describe "POST /api/v1/auths/register" do
    let(:valid_attributes) do
      {
        name: "Test User",
        email: "test@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    end

    context "with valid parameters" do
      it "returns a success response" do
        post "/api/v1/auths/register", params: valid_attributes
        expect(response).to have_http_status(:created)
      end

      it "creates a new User" do
        expect do
          post "/api/v1/auths/register", params: valid_attributes
        end.to change(User, :count).by(1)
      end

      it "returns a token" do
        post "/api/v1/auths/register", params: valid_attributes
        expect(JSON.parse(response.body)).to include("token")
      end
    end

    context "with invalid parameters" do
      it "returns a failure response" do
        post "/api/v1/auths/register", params: {email: "test@example.com"}
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "does not create a new User" do
        expect do
          post "/api/v1/auths/register", params: {email: "test@example.com"}
        end.to change(User, :count).by(0)
      end
    end
  end

  describe "POST /api/v1/auths/login" do
    let!(:user) { create(:user, email: "test@example.com", password: "password123") }

    context "with valid credentials" do
      it "returns a success response" do
        post "/api/v1/auths/login", params: {email: "test@example.com", password: "password123"}
        expect(response).to have_http_status(:ok)
      end

      it "returns a token" do
        post "/api/v1/auths/login", params: {email: "test@example.com", password: "password123"}
        expect(JSON.parse(response.body)).to include("token")
      end
    end

    context "with invalid credentials" do
      it "returns an unauthorized response" do
        post "/api/v1/auths/login", params: {email: "test@example.com", password: "wrongpassword"}
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
