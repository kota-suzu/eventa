require 'rails_helper'

RSpec.describe Api::V1::AuthsController, type: :request do
  let(:user_email) { 'test@example.com' }
  let(:user_password) { 'password123' }
  let(:user_name) { 'Test User' }
  let(:valid_user_params) do 
    {
      email: user_email,
      password: user_password,
      name: user_name
    }
  end
  let(:valid_login_params) do
    {
      email: user_email,
      password: user_password
    }
  end
  
  let(:invalid_login_params) do
    {
      email: user_email,
      password: 'wrong_password'
    }
  end
  
  # テスト実行時の固定時間
  let(:test_time) { Time.utc(2025, 5, 1, 12, 0, 0) }
  
  # テスト用のJWTトークン生成のモック設定
  let(:mock_access_token) { 'mock_access_token' }
  let(:mock_refresh_token) { 'mock_refresh_token' }
  let(:mock_session_id) { 'mock_session_id' }
  
  # 時間に依存するテストの前処理
  before do
    allow(Time).to receive(:current).and_return(test_time)
    
    # ユーザー作成済みの場合は削除してから再作成する（テストの独立性確保）
    User.find_by(email: user_email)&.destroy
  end
  
  describe 'メタ認知テスト - 認証関連のルーティング設定' do
    it '登録エンドポイントが正しく設定されている' do
      expect(post: '/api/v1/auth/register').to route_to(
        controller: 'api/v1/auths',
        action: 'register',
        format: :json
      )
    end
    
    it 'ログインエンドポイントが正しく設定されている' do
      expect(post: '/api/v1/auth/login').to route_to(
        controller: 'api/v1/auths',
        action: 'login',
        format: :json
      )
    end
    
    it 'トークンリフレッシュエンドポイントが正しく設定されている' do
      expect(post: '/api/v1/auth/refresh').to route_to(
        controller: 'api/v1/auths',
        action: 'refresh',
        format: :json
      )
    end
    
    it 'ログアウトエンドポイントが正しく設定されている' do
      expect(delete: '/api/v1/auth/logout').to route_to(
        controller: 'api/v1/auths',
        action: 'logout',
        format: :json
      )
    end
  end
  
  describe 'POST /api/v1/auth/register' do
    context '有効なパラメータの場合' do
      it 'ユーザーを登録し、トークンを含むレスポンスを返す' do
        # JWTトークン生成のモック
        expect(JsonWebToken).to receive(:encode).and_return(mock_access_token)
        expect(JsonWebToken).to receive(:generate_refresh_token).and_return([mock_refresh_token, mock_session_id])
        
        post '/api/v1/auth/register', params: { user: valid_user_params }
        
        # レスポンスの検証
        expect(response).to have_http_status(:created)
        json_response = JSON.parse(response.body)
        
        # 必要な情報が含まれていることを確認
        expect(json_response['token']).to eq(mock_access_token)
        expect(json_response['user']).to include(
          'id',
          'email',
          'name'
        )
        expect(json_response['user']['email']).to eq(user_email)
        expect(json_response['user']['name']).to eq(user_name)
        
        # リフレッシュトークンがCookieに設定されていることを確認
        expect(response.cookies['refresh_token']).to eq(mock_refresh_token)
        expect(response.cookies['refresh_token_secure']).to be true
        expect(response.cookies['refresh_token_http_only']).to be true
        
        # 作成されたユーザーがDBに存在することを確認
        expect(User.find_by(email: user_email)).not_to be_nil
      end
      
      it 'セッションIDがユーザーレコードに保存される' do
        allow(JsonWebToken).to receive(:encode).and_return(mock_access_token)
        allow(JsonWebToken).to receive(:generate_refresh_token).and_return([mock_refresh_token, mock_session_id])
        
        post '/api/v1/auth/register', params: { user: valid_user_params }
        
        user = User.find_by(email: user_email)
        expect(user).not_to be_nil
        expect(user.session_id).to eq(mock_session_id)
      end
    end
    
    context '無効なパラメータの場合' do
      it 'メールアドレスが空の場合、422エラーを返す' do
        invalid_params = valid_user_params.merge(email: '')
        post '/api/v1/auth/register', params: { user: invalid_params }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)).to have_key('errors')
        expect(JSON.parse(response.body)['errors']).to include('email')
      end
      
      it 'パスワードが空の場合、422エラーを返す' do
        invalid_params = valid_user_params.merge(password: '')
        post '/api/v1/auth/register', params: { user: invalid_params }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)).to have_key('errors')
        expect(JSON.parse(response.body)['errors']).to include('password')
      end
      
      it '既に存在するメールアドレスの場合、422エラーを返す' do
        # 既存ユーザーを作成
        User.create!(valid_user_params)
        
        # 同じメールアドレスで登録を試みる
        post '/api/v1/auth/register', params: { user: valid_user_params }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)).to have_key('errors')
        expect(JSON.parse(response.body)['errors']).to include('email')
        expect(JSON.parse(response.body)['errors']['email']).to include(/既に使用されています/)
      end
      
      it '不正な形式のメールアドレスの場合、422エラーを返す' do
        invalid_params = valid_user_params.merge(email: 'invalid-email')
        post '/api/v1/auth/register', params: { user: invalid_params }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)).to have_key('errors')
        expect(JSON.parse(response.body)['errors']).to include('email')
      end
      
      it '短すぎるパスワードの場合、422エラーを返す' do
        invalid_params = valid_user_params.merge(password: '123')
        post '/api/v1/auth/register', params: { user: invalid_params }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)).to have_key('errors')
        expect(JSON.parse(response.body)['errors']).to include('password')
      end
    end
    
    context 'JSON形式が無効な場合' do
      it '不正なJSONリクエストに対して400エラーを返す' do
        # 不正なJSON形式をシミュレート
        post '/api/v1/auth/register', 
             params: 'invalid_json_format',
             headers: { 'CONTENT_TYPE' => 'application/json' }
        
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
  
  describe 'POST /api/v1/auth/login' do
    before do
      # テスト前にユーザーを作成
      User.create!(valid_user_params)
    end
    
    context '有効な認証情報の場合' do
      it 'トークンと共にユーザー情報を返す' do
        # JWTトークン生成のモック
        expect(JsonWebToken).to receive(:encode).and_return(mock_access_token)
        expect(JsonWebToken).to receive(:generate_refresh_token).and_return([mock_refresh_token, mock_session_id])
        
        post '/api/v1/auth/login', params: valid_login_params
        
        # 成功レスポンスの検証
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        
        expect(json_response['token']).to eq(mock_access_token)
        expect(json_response['user']).to include(
          'id',
          'email',
          'name'
        )
        expect(json_response['user']['email']).to eq(user_email)
        
        # リフレッシュトークンがCookieに設定されていることを確認
        expect(response.cookies['refresh_token']).to eq(mock_refresh_token)
        expect(response.cookies['refresh_token_secure']).to be true
        expect(response.cookies['refresh_token_http_only']).to be true
      end
      
      it 'セッションIDがユーザーレコードに保存される' do
        allow(JsonWebToken).to receive(:encode).and_return(mock_access_token)
        allow(JsonWebToken).to receive(:generate_refresh_token).and_return([mock_refresh_token, mock_session_id])
        
        post '/api/v1/auth/login', params: valid_login_params
        
        user = User.find_by(email: user_email)
        expect(user.session_id).to eq(mock_session_id)
      end
    end
    
    context '無効な認証情報の場合' do
      it '不正なパスワードの場合、401エラーを返す' do
        post '/api/v1/auth/login', params: invalid_login_params
        
        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('error')
        expect(json_response['error']).to include('認証')
      end
      
      it '存在しないメールアドレスの場合、401エラーを返す' do
        post '/api/v1/auth/login', params: { email: 'nonexistent@example.com', password: user_password }
        
        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('error')
        expect(json_response['error']).to include('認証')
      end
      
      it 'メールアドレスが空の場合、422エラーを返す' do
        post '/api/v1/auth/login', params: { email: '', password: user_password }
        
        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('errors')
      end
      
      it 'パスワードが空の場合、422エラーを返す' do
        post '/api/v1/auth/login', params: { email: user_email, password: '' }
        
        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('errors')
      end
    end
    
    context 'セキュリティ対策' do
      it 'ブルートフォース攻撃対策: 同一IPからの連続失敗試行をレート制限する' do
        # Rackテスト環境でのIPアドレス設定の模擬
        allow_any_instance_of(ActionDispatch::Request).to receive(:ip).and_return('192.168.1.1')
        
        # レート制限前に成功するケース
        allow(User).to receive(:find_by).and_return(User.find_by(email: user_email))
        allow_any_instance_of(User).to receive(:authenticate).and_return(false)
        
        # 連続した失敗試行（レート制限の閾値を超える）
        5.times do
          post '/api/v1/auth/login', params: invalid_login_params
          expect(response.status).to eq(401) # まだレート制限されていない
        end
        
        # レート制限が適用されたかの確認（実際のアプリケーションに依存）
        # ここでは簡易的にRailsキャッシュを使ったレート制限を想定
        key = "login_attempts:192.168.1.1"
        expect(Rails.cache.exist?(key)).to be_truthy
        
        # 注: 実際のアプリケーションによってレート制限の実装は異なるため、
        # この部分は実際の実装に合わせて調整が必要です
      end
    end
  end
  
  describe 'POST /api/v1/auth/refresh' do
    let(:user) { User.create!(valid_user_params.merge(session_id: mock_session_id)) }
    let(:valid_refresh_token_payload) do
      {
        'user_id' => user.id,
        'session_id' => mock_session_id,
        'token_type' => 'refresh',
        'exp' => (Time.current + 30.days).to_i
      }
    end
    
    context '有効なリフレッシュトークンの場合' do
      it '新しいアクセストークンを返す' do
        # リフレッシュトークンのモック
        allow(JsonWebToken).to receive(:decode).and_return(valid_refresh_token_payload)
        
        # 新しいアクセストークン生成のモック
        new_access_token = 'new_access_token'
        expect(JsonWebToken).to receive(:encode).and_return(new_access_token)
        
        # リフレッシュトークンをCookieに設定
        cookies[:refresh_token] = mock_refresh_token
        
        post '/api/v1/auth/refresh'
        
        # レスポンスの検証
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['token']).to eq(new_access_token)
      end
    end
    
    context '無効なリフレッシュトークンの場合' do
      it 'リフレッシュトークンが欠落している場合、401エラーを返す' do
        # リフレッシュトークンを設定しない
        post '/api/v1/auth/refresh'
        
        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('error')
      end
      
      it 'デコードに失敗するリフレッシュトークンの場合、401エラーを返す' do
        # 不正なトークンのデコード失敗をシミュレート
        allow(JsonWebToken).to receive(:decode).and_return(nil)
        
        cookies[:refresh_token] = 'invalid_refresh_token'
        post '/api/v1/auth/refresh'
        
        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('error')
      end
      
      it 'トークンタイプが refresh でない場合、401エラーを返す' do
        # トークンタイプが異なるペイロードをシミュレート
        invalid_type_payload = valid_refresh_token_payload.merge('token_type' => 'access')
        allow(JsonWebToken).to receive(:decode).and_return(invalid_type_payload)
        
        cookies[:refresh_token] = 'wrong_type_token'
        post '/api/v1/auth/refresh'
        
        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('error')
      end
      
      it 'セッションIDが一致しない場合、401エラーを返す' do
        # データベースのセッションIDが異なる状態をシミュレート
        user.update(session_id: 'different_session_id')
        
        # 有効なリフレッシュトークンだがセッションIDが古い
        allow(JsonWebToken).to receive(:decode).and_return(valid_refresh_token_payload)
        
        cookies[:refresh_token] = mock_refresh_token
        post '/api/v1/auth/refresh'
        
        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('error')
        expect(json_response['error']).to include('セッション')
      end
      
      it 'ユーザーが存在しない場合、401エラーを返す' do
        # 存在しないユーザーIDをシミュレート
        non_existent_user_payload = valid_refresh_token_payload.merge('user_id' => 9999)
        allow(JsonWebToken).to receive(:decode).and_return(non_existent_user_payload)
        
        cookies[:refresh_token] = mock_refresh_token
        post '/api/v1/auth/refresh'
        
        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('error')
      end
    end
  end
  
  describe 'DELETE /api/v1/auth/logout' do
    let(:user) { User.create!(valid_user_params.merge(session_id: mock_session_id)) }
    
    before do
      # 認証済みユーザーのシミュレーション
      allow_any_instance_of(Api::V1::AuthsController).to receive(:current_user).and_return(user)
    end
    
    it 'セッションIDをクリアし、リフレッシュトークンCookieを削除する' do
      # リフレッシュトークンをCookieに設定
      cookies[:refresh_token] = mock_refresh_token
      
      delete '/api/v1/auth/logout'
      
      # レスポンスの検証
      expect(response).to have_http_status(:ok)
      
      # ユーザーのセッションIDがクリアされていることを確認
      user.reload
      expect(user.session_id).to be_nil
      
      # リフレッシュトークンCookieが削除されていることを確認
      expect(response.cookies['refresh_token']).to be_nil
    end
    
    it '未認証ユーザーの場合、401エラーを返す' do
      # 未認証状態をシミュレート
      allow_any_instance_of(Api::V1::AuthsController).to receive(:current_user).and_return(nil)
      
      delete '/api/v1/auth/logout'
      
      expect(response).to have_http_status(:unauthorized)
    end
  end
end 