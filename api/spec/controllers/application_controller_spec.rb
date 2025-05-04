require "rails_helper"

RSpec.describe ApplicationController, type: :controller do
  # テスト用のモックコントローラー
  controller do
    # 認証を必要とするアクション
    def secured_action
      render json: {message: "認証成功", user_id: current_user.id}
    end

    # 認証をスキップするアクション
    skip_before_action :authenticate_user, only: [:public_action]
    def public_action
      render json: {message: "公開アクション"}
    end
  end

  before do
    routes.draw do
      get "secured_action" => "anonymous#secured_action"
      get "public_action" => "anonymous#public_action"
    end
  end

  describe "認証が必要なアクション" do
    let(:user) { create(:user) }

    context "有効なトークンがある場合" do
      before do
        token = JsonWebToken.encode({user_id: user.id})
        request.headers["Authorization"] = "Bearer #{token}"
      end

      it "アクセスを許可する" do
        get :secured_action
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["message"]).to eq("認証成功")
        expect(json["user_id"]).to eq(user.id)
      end
    end

    context "トークンがない場合" do
      it "401エラーを返す" do
        get :secured_action
        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json).to have_key("error")
      end
    end

    context "無効なトークンの場合" do
      before do
        request.headers["Authorization"] = "Bearer invalid_token"
      end

      it "401エラーを返す" do
        get :secured_action
        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json).to have_key("error")
      end
    end

    context "存在しないユーザーIDのトークンの場合" do
      before do
        token = JsonWebToken.encode({user_id: 99999})
        request.headers["Authorization"] = "Bearer #{token}"
      end

      it "401エラーを返す" do
        get :secured_action
        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json).to have_key("error")
      end
    end
  end

  describe "認証をスキップするアクション" do
    it "トークンなしでアクセスできる" do
      get :public_action
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["message"]).to eq("公開アクション")
    end
  end
end
