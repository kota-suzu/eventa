# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Auth", type: :request do
  describe "POST /api/v1/auth/register" do
    let(:valid_attributes) {
      {
        user: {
          email: "test@example.com",
          name: "Test User",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    }

    let(:invalid_attributes) {
      {
        user: {
          email: "invalid-email",
          name: "",
          password: "short",
          password_confirmation: "different"
        }
      }
    }

    before do
      # すべてのテストをスキップ
      skip "APIエンドポイントが完全に実装されるまでskip"
    end

    context "with valid parameters" do
      it "creates a new User" do
        expect {
          post "/api/v1/auth/register", params: valid_attributes
        }.to change(User, :count).by(1)
      end

      it "renders a JSON response with the new user" do
        post "/api/v1/auth/register", params: valid_attributes
        expect(response).to have_http_status(:created)
        expect(response.content_type).to match(a_string_including("application/json"))

        json_response = JSON.parse(response.body)
        expect(json_response).to include("user", "token")
        expect(json_response["user"]).to include(
          "id", "name", "email", "bio", "created_at"
        )
        expect(json_response["user"]["email"]).to eq("test@example.com")
        expect(json_response["user"]["name"]).to eq("Test User")
        expect(json_response["token"]).not_to be_empty
      end
    end

    context "with invalid parameters" do
      it "does not create a new User" do
        expect {
          post "/api/v1/auth/register", params: invalid_attributes
        }.to change(User, :count).by(0)
      end

      it "renders a JSON response with errors for the new user" do
        post "/api/v1/auth/register", params: invalid_attributes
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.content_type).to match(a_string_including("application/json"))

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key("errors")
        expect(json_response["errors"]).to be_an(Array)
        expect(json_response["errors"]).not_to be_empty
      end
    end

    context "with duplicate email" do
      before { create(:user, email: "test@example.com") }

      it "does not create a new User" do
        expect {
          post "/api/v1/auth/register", params: valid_attributes
        }.not_to change(User, :count)
      end

      it "renders a JSON response with errors" do
        post "/api/v1/auth/register", params: valid_attributes
        expect(response).to have_http_status(:unprocessable_entity)

        json_response = JSON.parse(response.body)
        expect(json_response["errors"]).to include("メールアドレス はすでに存在します")
      end
    end
  end

  describe "POST /api/v1/auth/login" do
    let(:user) { create(:user, email: "login@example.com", password: "password123") }

    before do
      # すべてのテストをスキップ
      skip "APIエンドポイントが完全に実装されるまでskip"
    end

    it "returns a token when credentials are valid" do
      post "/api/v1/auth/login", params: {email: user.email, password: "password123"}

      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response).to include("user", "token")
      expect(json_response["user"]["id"]).to eq(user.id)
      expect(json_response["token"]).not_to be_empty
    end

    it "returns unauthorized when credentials are invalid" do
      post "/api/v1/auth/login", params: {email: user.email, password: "wrong_password"}

      expect(response).to have_http_status(:unauthorized)
      json_response = JSON.parse(response.body)
      expect(json_response).to have_key("error")
    end
  end
end
