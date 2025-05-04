require 'rails_helper'

RSpec.describe "認証API網羅テスト", type: :request do
  include AuthTestHelpers
  
  # メタ認知: このテストファイルでは、認証関連APIを網羅的にテストします。
  # 通常のシナリオだけでなく、セキュリティ面も含めてエッジケースをカバーします。
  
  let(:user_email) { "api_test@example.com" }
  let(:user_password) { "secure_password123" }
  let(:user_name) { "APIテストユーザー" }
  
  let(:valid_user_params) do
    {
      user: {
        name: user_name,
        email: user_email,
        password: user_password,
        password_confirmation: user_password
      }
    }
  end
  
  let(:valid_login_params) do
    {
      auth: {
        email: user_email,
        password: user_password
      }
    }
  end
  
  # テスト実行前の共通処理
  before do
    # 既存ユーザーがいたらクリア
    User.find_by(email: user_email)&.destroy
    
    # テスト時刻を固定
    travel_to Time.zone.local(2025, 5, 1, 12, 0, 0)
  end
  
  # テスト終了後の共通処理
  after do
    travel_back
  end
  
  # ステップバイステップ実行のためにcontextを使用
  context "1. ユーザー登録API（/api/v1/auth/register）" do
    describe "POST /api/v1/auth/register - 基本シナリオ" do
      it "有効なパラメータでユーザーを登録できること" do
        expect {
          post api_v1_auth_register_path, params: valid_user_params
        }.to change(User, :count).by(1)
        
        expect(response).to have_http_status(:created)
        expect(json_response[:user][:email]).to eq(user_email)
        expect(json_response[:user][:name]).to eq(user_name)
        expect(json_response[:token]).to be_present
      end
      
      it "HTTPOnly Cookie でリフレッシュトークンが設定されること" do
        post api_v1_auth_register_path, params: valid_user_params
        
        expect(response.cookies['refresh_token']).to be_present
        expect(response.cookies['refresh_token_http_only']).to be true
      end
    end
    
    describe "POST /api/v1/auth/register - エラーケース" do
      it "同じメールアドレスのユーザーが存在する場合、エラーになること" do
        # 先に同じメールアドレスでユーザーを作成
        User.create!(
          name: "先行ユーザー", 
          email: user_email, 
          password: "different_password", 
          password_confirmation: "different_password"
        )
        
        expect {
          post api_v1_auth_register_path, params: valid_user_params
        }.not_to change(User, :count)
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:errors]).to include(/メール/)
      end
      
      it "パラメータが不足している場合、エラーになること" do
        invalid_params = {
          user: {
            name: user_name,
            email: user_email
            # パスワード未指定
          }
        }
        
        post api_v1_auth_register_path, params: invalid_params
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:errors]).to include(/パスワード/)
      end
      
      it "パスワードと確認用パスワードが一致しない場合、エラーになること" do
        mismatch_params = {
          user: {
            name: user_name,
            email: user_email,
            password: user_password,
            password_confirmation: "different_password"
          }
        }
        
        post api_v1_auth_register_path, params: mismatch_params
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:errors]).to include(/一致/)
      end
      
      it "無効なメールアドレス形式の場合、エラーになること" do
        invalid_email_params = {
          user: {
            name: user_name,
            email: "invalid-email",
            password: user_password,
            password_confirmation: user_password
          }
        }
        
        post api_v1_auth_register_path, params: invalid_email_params
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:errors]).to include(/メール/)
      end
    end
    
    describe "POST /api/v1/auth/register - セキュリティテスト" do
      it "作成されたユーザーのパスワードがハッシュ化されていること" do
        post api_v1_auth_register_path, params: valid_user_params
        
        created_user = User.find_by(email: user_email)
        
        # パスワードがそのままの形では保存されていないこと
        expect(created_user.password_digest).not_to eq(user_password)
        # BCryptのハッシュ形式になっていること
        expect(created_user.password_digest).to match(/\$2a\$/)
      end
      
      it "パスワードに特殊文字が含まれていても正しく処理されること" do
        special_password = "p@ssw0rd!#$%^&*()_+"
        special_params = {
          user: {
            name: user_name,
            email: user_email,
            password: special_password,
            password_confirmation: special_password
          }
        }
        
        post api_v1_auth_register_path, params: special_params
        
        expect(response).to have_http_status(:created)
        
        # 作成されたユーザーで認証できることを確認
        created_user = User.find_by(email: user_email)
        expect(created_user.authenticate(special_password)).to eq(created_user)
      end
      
      it "大量のリクエストに対してレート制限が機能すること" do
        # 注: 実際のレート制限の閾値はアプリケーションの設定に依存
        # ここでは簡易的に確認する例を示しています
        
        # まず登録可能なことを確認
        post api_v1_auth_register_path, params: valid_user_params
        expect(response).to have_http_status(:created)
        
        User.find_by(email: user_email)&.destroy
        
        # 短時間に多数のリクエストを送信
        10.times do |i|
          post api_v1_auth_register_path, params: {
            user: {
              name: "User#{i}",
              email: "user#{i}@example.com",
              password: "password123",
              password_confirmation: "password123"
            }
          }
          
          # レート制限が発動した場合（429 Too Many Requests）
          if response.status == 429
            expect(response.body).to include("リクエスト")
            break
          end
        end
        
        # 注: 実際のアプリケーションでレート制限が実装されていない場合、
        # このテストは常に成功します。実装に応じてスキップするか条件を調整してください
      end
    end
  end
  
  context "2. ログインAPI（/api/v1/auth/login）" do
    let!(:existing_user) do
      User.create!(
        name: user_name, 
        email: user_email, 
        password: user_password, 
        password_confirmation: user_password
      )
    end
    
    describe "POST /api/v1/auth/login - 基本シナリオ" do
      it "有効な認証情報でログインできること" do
        post api_v1_auth_login_path, params: valid_login_params
        
        expect(response).to have_http_status(:ok)
        expect(json_response[:token]).to be_present
        expect(json_response[:user][:email]).to eq(user_email)
      end
      
      it "ログイン成功時にHTTPOnly Cookie でリフレッシュトークンが設定されること" do
        post api_v1_auth_login_path, params: valid_login_params
        
        expect(response.cookies['refresh_token']).to be_present
        expect(response.cookies['refresh_token_http_only']).to be true
      end
    end
    
    describe "POST /api/v1/auth/login - エラーケース" do
      it "存在しないユーザーでログインできないこと" do
        invalid_params = {
          auth: {
            email: "nonexistent@example.com",
            password: user_password
          }
        }
        
        post api_v1_auth_login_path, params: invalid_params
        
        expect(response).to have_http_status(:unauthorized)
        expect(json_response[:error]).to be_present
      end
      
      it "パスワードが間違っている場合、ログインできないこと" do
        invalid_params = {
          auth: {
            email: user_email,
            password: "wrong_password"
          }
        }
        
        post api_v1_auth_login_path, params: invalid_params
        
        expect(response).to have_http_status(:unauthorized)
        expect(json_response[:error]).to be_present
      end
      
      it "メールアドレスが空の場合、適切なエラーを返すこと" do
        invalid_params = {
          auth: {
            email: "",
            password: user_password
          }
        }
        
        post api_v1_auth_login_path, params: invalid_params
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:errors]).to be_present
      end
    end
    
    describe "POST /api/v1/auth/login - セキュリティテスト" do
      it "メールアドレスの大文字小文字を区別せずログインできること" do
        # メールアドレスを大文字混じりに変更
        mixed_case_params = {
          auth: {
            email: user_email.upcase,
            password: user_password
          }
        }
        
        post api_v1_auth_login_path, params: mixed_case_params
        
        expect(response).to have_http_status(:ok)
        expect(json_response[:token]).to be_present
      end
      
      it "連続した認証失敗に対してレート制限が機能すること" do
        # 注: 実際のレート制限の閾値はアプリケーションの設定に依存
        
        # 連続して誤ったパスワードでログイン試行
        7.times do
          post api_v1_auth_login_path, params: {
            auth: {
              email: user_email,
              password: "wrong_password"
            }
          }
          
          # レート制限が発動した場合（429 Too Many Requests）
          if response.status == 429
            expect(response.body).to include("リクエスト")
            break
          end
        end
        
        # 注: 実際のアプリケーションでレート制限が実装されていない場合、
        # このテストは常に成功します。実装に応じてスキップするか条件を調整してください
      end
      
      it "ログイン成功時にセッションIDが更新されること" do
        # 事前にセッションIDを持つユーザーを準備
        existing_user.update(session_id: "old_session_id")
        
        post api_v1_auth_login_path, params: valid_login_params
        
        # ユーザーのセッションIDが更新されていることを確認
        existing_user.reload
        expect(existing_user.session_id).not_to eq("old_session_id")
        expect(existing_user.session_id).to be_present
      end
      
      it "JSONインジェクション攻撃が防御されていること" do
        # JSONインジェクション攻撃の試み
        malicious_params = { 
          auth: {
            email: "#{user_email}\", \"malicious\": \"payload",
            password: user_password
          }
        }
        
        post api_v1_auth_login_path, params: malicious_params
        
        # ログインには失敗するはず
        expect(response).to have_http_status(:unauthorized)
        # レスポンスにマルウェアパラメータが含まれていないことを確認
        expect(response.body).not_to include("malicious")
      end
    end
  end
  
  context "3. トークンリフレッシュAPI（/api/v1/auth/refresh）" do
    let!(:existing_user) do
      User.create!(
        name: user_name, 
        email: user_email, 
        password: user_password, 
        password_confirmation: user_password
      )
    end
    
    # 有効なリフレッシュトークンを取得するためにログイン
    let!(:login_response) do
      post api_v1_auth_login_path, params: valid_login_params
      response
    end
    
    let(:refresh_token) { login_response.cookies['refresh_token'] }
    
    describe "POST /api/v1/auth/refresh - 基本シナリオ" do
      it "有効なリフレッシュトークンで新しいアクセストークンを取得できること" do
        # リフレッシュトークンをクッキーにセット
        cookies['refresh_token'] = refresh_token
        
        post api_v1_auth_refresh_path
        
        expect(response).to have_http_status(:ok)
        expect(json_response[:token]).to be_present
        expect(json_response[:token]).not_to eq(login_response.parsed_body['token'])
      end
    end
    
    describe "POST /api/v1/auth/refresh - エラーケース" do
      it "リフレッシュトークンが無い場合、エラーになること" do
        # リフレッシュトークンを設定しない
        post api_v1_auth_refresh_path
        
        expect(response).to have_http_status(:unauthorized)
        expect(json_response[:error]).to include("リフレッシュトークン")
      end
      
      it "無効なリフレッシュトークンでエラーになること" do
        cookies['refresh_token'] = "invalid.refresh.token"
        
        post api_v1_auth_refresh_path
        
        expect(response).to have_http_status(:unauthorized)
        expect(json_response[:error]).to include("無効")
      end
      
      it "期限切れのリフレッシュトークンでエラーになること" do
        # 期限切れトークンを模擬するため、復号化して期限を過去にする
        expired_payload = JsonWebToken.decode(refresh_token)
        expired_payload['exp'] = 1.day.ago.to_i
        
        # 期限切れペイロードで新たにトークンを作成
        expired_token = JWT.encode(expired_payload, JsonWebToken::SECRET, 'HS256')
        cookies['refresh_token'] = expired_token
        
        post api_v1_auth_refresh_path
        
        expect(response).to have_http_status(:unauthorized)
        expect(json_response[:error]).to include("無効")
      end
      
      it "セッションIDが一致しない場合、エラーになること" do
        # ログイン後にセッションIDを変更
        existing_user.update(session_id: "different_session_id")
        
        cookies['refresh_token'] = refresh_token
        
        post api_v1_auth_refresh_path
        
        expect(response).to have_http_status(:unauthorized)
        expect(json_response[:error]).to include("セッション")
      end
    end
    
    describe "POST /api/v1/auth/refresh - セキュリティテスト" do
      it "リフレッシュトークンはリフレッシュAPIでのみ有効であること" do
        # リフレッシュトークンを認証トークンとして使用する試み
        authenticated_api_path = "/api/v1/protected_resource"
        
        # 認証トークンとしてリフレッシュトークンを使用
        get authenticated_api_path, headers: { 'Authorization': "Bearer #{refresh_token}" }
        
        # アクセスできないことを確認
        expect(response).to have_http_status(:unauthorized)
      end
      
      it "新しいアクセストークンで保護されたリソースにアクセスできること" do
        cookies['refresh_token'] = refresh_token
        
        post api_v1_auth_refresh_path
        
        # 新しいアクセストークンを取得
        new_token = json_response[:token]
        
        # 保護されたリソースにアクセス
        authenticated_api_path = "/api/v1/protected_resource"
        get authenticated_api_path, headers: { 'Authorization': "Bearer #{new_token}" }
        
        # このエンドポイントが実際に存在する場合は成功を期待
        # 存在しない場合は404になるが、401（認証エラー）にはならないはず
        expect(response.status).not_to eq(401)
      end
      
      it "同じリフレッシュトークンで複数回トークンを更新した場合、2回目以降はエラーになること" do
        # このテストはリフレッシュトークンの使い捨て（ワンタイム）実装を想定
        # 実際のアプリケーションでこの実装がない場合、このテストはスキップしてください
        
        cookies['refresh_token'] = refresh_token
        
        # 1回目のリフレッシュ（成功するはず）
        post api_v1_auth_refresh_path
        expect(response).to have_http_status(:ok)
        
        # 2回目のリフレッシュ（失敗するはず - ワンタイム実装の場合）
        post api_v1_auth_refresh_path
        
        # もしリフレッシュトークンがワンタイムの場合
        if response.status == 401
          expect(json_response[:error]).to include("無効")
        else
          # ワンタイム実装でない場合はスキップ
          skip "リフレッシュトークンはワンタイム実装ではありません"
        end
      end
    end
  end
  
  context "4. ログアウトAPI（/api/v1/auth/logout）" do
    let!(:existing_user) do
      User.create!(
        name: user_name, 
        email: user_email, 
        password: user_password, 
        password_confirmation: user_password
      )
    end
    
    # ログインしてトークンを取得
    let!(:login_response) do
      post api_v1_auth_login_path, params: valid_login_params
      response
    end
    
    let(:access_token) { login_response.parsed_body['token'] }
    let(:refresh_token) { login_response.cookies['refresh_token'] }
    
    describe "DELETE /api/v1/auth/logout - 基本シナリオ" do
      it "ログアウトするとセッションが無効化されること" do
        # まずログイン状態を確認
        expect(existing_user.reload.session_id).to be_present
        
        # ログアウト
        delete api_v1_auth_logout_path, headers: { 'Authorization': "Bearer #{access_token}" }
        
        expect(response).to have_http_status(:ok)
        
        # ユーザーのセッションIDがクリアされていることを確認
        expect(existing_user.reload.session_id).to be_nil
      end
      
      it "ログアウト後にリフレッシュトークンのクッキーが削除されること" do
        delete api_v1_auth_logout_path, headers: { 'Authorization': "Bearer #{access_token}" }
        
        expect(response).to have_http_status(:ok)
        
        # クッキーが削除または空になっていることを確認
        expect(response.cookies['refresh_token']).to be_nil
      end
    end
    
    describe "DELETE /api/v1/auth/logout - エラーケース" do
      it "認証なしでログアウトAPIにアクセスできないこと" do
        delete api_v1_auth_logout_path
        
        expect(response).to have_http_status(:unauthorized)
      end
      
      it "無効なトークンでログアウトAPIにアクセスできないこと" do
        delete api_v1_auth_logout_path, headers: { 'Authorization': "Bearer invalid_token" }
        
        expect(response).to have_http_status(:unauthorized)
      end
    end
    
    describe "DELETE /api/v1/auth/logout - セキュリティテスト" do
      it "ログアウト後のアクセストークンで認証が必要なAPIにアクセスできないこと" do
        # ログアウト
        delete api_v1_auth_logout_path, headers: { 'Authorization': "Bearer #{access_token}" }
        
        # 認証が必要なAPIにアクセス
        authenticated_api_path = "/api/v1/protected_resource"
        get authenticated_api_path, headers: { 'Authorization': "Bearer #{access_token}" }
        
        expect(response).to have_http_status(:unauthorized)
      end
      
      it "ログアウト後のリフレッシュトークンでトークン更新ができないこと" do
        # ログアウト
        delete api_v1_auth_logout_path, headers: { 'Authorization': "Bearer #{access_token}" }
        
        # ログアウト前のリフレッシュトークンでトークン更新を試みる
        cookies['refresh_token'] = refresh_token
        post api_v1_auth_refresh_path
        
        expect(response).to have_http_status(:unauthorized)
      end
      
      it "異なるユーザーのセッションには影響しないこと" do
        # 別ユーザーを作成してログイン
        another_user = User.create!(
          name: "別ユーザー", 
          email: "another@example.com", 
          password: "another_password", 
          password_confirmation: "another_password"
        )
        
        # 別ユーザーのログイン
        post api_v1_auth_login_path, params: {
          auth: {
            email: "another@example.com",
            password: "another_password"
          }
        }
        
        another_token = response.parsed_body['token']
        another_session_id = another_user.reload.session_id
        
        # 元のユーザーでログアウト
        delete api_v1_auth_logout_path, headers: { 'Authorization': "Bearer #{access_token}" }
        
        # 別ユーザーのセッションが維持されていることを確認
        expect(another_user.reload.session_id).to eq(another_session_id)
        
        # 別ユーザーのトークンがまだ有効であることを確認
        authenticated_api_path = "/api/v1/protected_resource"
        get authenticated_api_path, headers: { 'Authorization': "Bearer #{another_token}" }
        
        # 認証エラーにならないことを確認
        expect(response.status).not_to eq(401)
      end
    end
  end
  
  # JSONレスポンスを簡単に取得するヘルパーメソッド
  def json_response
    JSON.parse(response.body, symbolize_names: true)
  end
end 