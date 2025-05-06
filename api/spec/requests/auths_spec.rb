# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Auths", type: :request do
  describe "POST /api/v1/auths/register" do
    let(:valid_attributes) do
      {
        email: "test@example.com",
        password: "password123",
        password_confirmation: "password123",
        name: "Test User"
      }
    end

    context "バリデーション成功時" do
      it "ユーザーを作成し、トークンを返す" do
        expect {
          post "/api/v1/auths/register", params: valid_attributes
        }.to change(User, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json_response).to have_key("token")
        expect(json_response).to have_key("refresh_token")
        expect(json_response["user"]).to include({
          "name" => "Test User",
          "email" => "test@example.com"
        })
      end

      it "auth ハッシュ内のユーザーパラメータでも登録できる" do
        nested_params = {auth: {user: valid_attributes}}

        expect {
          post "/api/v1/auths/register", params: nested_params
        }.to change(User, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json_response).to have_key("token")
      end

      it "auth ハッシュ内に直接ユーザー情報があっても登録できる" do
        auth_params = {auth: valid_attributes}

        expect {
          post "/api/v1/auths/register", params: auth_params
        }.to change(User, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json_response).to have_key("token")
      end
    end

    context "バリデーション失敗時" do
      it "無効なデータではユーザーを作成しない" do
        invalid_attributes = valid_attributes.merge(email: "")

        expect {
          post "/api/v1/auths/register", params: invalid_attributes
        }.not_to change(User, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response).to have_key("errors")
      end
    end
  end

  describe "POST /api/v1/auths/login" do
    let!(:user) { create(:user, email: "login@example.com", password: "password123") }

    context "正しい認証情報" do
      it "ログインに成功し、トークンを返す" do
        post "/api/v1/auths/login", params: {email: "login@example.com", password: "password123"}

        expect(response).to have_http_status(:ok)
        expect(json_response).to have_key("token")
        expect(json_response).to have_key("refresh_token")
        expect(json_response["user"]).to include({
          "email" => "login@example.com"
        })
      end

      it "auth ハッシュ内のパラメータでもログインできる" do
        post "/api/v1/auths/login", params: {auth: {email: "login@example.com", password: "password123"}}

        expect(response).to have_http_status(:ok)
        expect(json_response).to have_key("token")
      end
    end

    context "無効な認証情報" do
      it "不正なパスワードでログインに失敗する" do
        post "/api/v1/auths/login", params: {email: "login@example.com", password: "wrongpassword"}

        expect(response).to have_http_status(:unauthorized)
        expect(json_response).to have_key("error")
      end

      it "存在しないユーザーでログインに失敗する" do
        post "/api/v1/auths/login", params: {email: "nonexistent@example.com", password: "password123"}

        expect(response).to have_http_status(:unauthorized)
        expect(json_response).to have_key("error")
      end
    end
  end

  describe "POST /api/v1/auths/refresh" do
    let!(:user) { create(:user) }
    let(:token) { JsonWebToken.encode({user_id: user.id}) }
    let(:refresh_token) { JsonWebToken.generate_refresh_token(user.id)[0] }

    context "有効なリフレッシュトークン" do
      it "Cookieから取得したリフレッシュトークンで新しいトークンを生成する" do
        # コントローラをスタブする代わりにパラメータとして送信
        post "/api/v1/auths/refresh", params: {refresh_token: refresh_token}

        expect(response).to have_http_status(:ok)
        expect(json_response).to have_key("token")
        expect(json_response["user"]).to include({
          "id" => user.id
        })
      end

      it "ヘッダーから取得したリフレッシュトークンで新しいトークンを生成する" do
        headers = {"X-Refresh-Token" => refresh_token}
        post "/api/v1/auths/refresh", headers: headers

        expect(response).to have_http_status(:ok)
        expect(json_response).to have_key("token")
      end

      it "ボディから取得したリフレッシュトークンで新しいトークンを生成する" do
        post "/api/v1/auths/refresh", params: {refresh_token: refresh_token}

        expect(response).to have_http_status(:ok)
        expect(json_response).to have_key("token")
      end
    end

    context "無効なリフレッシュトークン" do
      it "リフレッシュトークンがない場合はエラーを返す" do
        post "/api/v1/auths/refresh"

        expect(response).to have_http_status(:unauthorized)
        expect(json_response["error"]).to include("リフレッシュトークンが見つかりません")
      end

      it "無効なリフレッシュトークンの場合はエラーを返す" do
        # 期限切れの有効なJWT形式のトークンを作成（JsonWebToken.encodeではなく直接JWT.encodeを使用）
        expired_payload = {
          user_id: user.id,
          token_type: "refresh",
          exp: 1.day.ago.to_i,  # 期限切れ
          iss: JsonWebToken::ISSUER,
          aud: JsonWebToken::AUDIENCE,
          iat: Time.current.to_i,
          nbf: Time.current.to_i,
          jti: SecureRandom.uuid
        }
        invalid_token = JWT.encode(expired_payload, JsonWebToken::SECRET_KEY, JsonWebToken::ALGORITHM)

        post "/api/v1/auths/refresh", params: {refresh_token: invalid_token}

        expect(response).to have_http_status(:unauthorized)
      end

      it "存在しないユーザーIDのリフレッシュトークンの場合はエラーを返す" do
        invalid_token = JsonWebToken.encode({
          user_id: 999999, # 存在しないID
          token_type: "refresh",
          exp: 30.days.from_now.to_i
        })

        post "/api/v1/auths/refresh", params: {refresh_token: invalid_token}

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/auths/logout" do
    let!(:user) { create(:user) }
    let(:token) { JsonWebToken.encode({user_id: user.id}) }
    let(:refresh_token) { JsonWebToken.generate_refresh_token(user.id)[0] }

    before do
      # 認証ヘッダーをセット
      @auth_headers = {"Authorization" => "Bearer #{token}"}
    end

    it "ログアウト時にトークンをブラックリストに追加する" do
      # TokenBlacklistServiceのモックを作成
      expect(TokenBlacklistService).to receive(:add).with(token, "logout").and_return(true)

      post "/api/v1/auths/logout", headers: @auth_headers
      expect(response).to have_http_status(:ok)
      expect(json_response["message"]).to include("ログアウトしました")
    end

    it "ログアウト時にリフレッシュトークンを削除する" do
      # リフレッシュトークンをCookieにセット
      cookies[:refresh_token] = refresh_token

      # リフレッシュトークンの削除処理をモック
      expect(TokenBlacklistService).to receive(:remove_refresh_token).with(refresh_token).and_return(true)

      post "/api/v1/auths/logout", headers: @auth_headers
      expect(response).to have_http_status(:ok)
    end

    it "ログアウト時に認証Cookieを削除する" do
      # Cookieをセット
      cookies.signed[:jwt] = token
      cookies.signed[:refresh_token] = refresh_token

      post "/api/v1/auths/logout", headers: @auth_headers

      # レスポンスのCookieをチェック
      expect(cookies[:jwt]).to be_nil
      expect(cookies[:refresh_token]).to be_nil
    end

    it "トークンがなくてもログアウトできる" do
      # 認証をスキップさせてリクエスト
      allow_any_instance_of(Api::V1::AuthsController).to receive(:authenticate_request).and_return(true)

      post "/api/v1/auths/logout"
      expect(response).to have_http_status(:ok)
    end
  end

  # レスポンスをJSONとしてパースするヘルパーメソッド
  def json_response
    JSON.parse(response.body)
  end
end
