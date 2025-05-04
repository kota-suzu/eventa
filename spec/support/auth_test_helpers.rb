# spec/support/auth_test_helpers.rb
# 認証関連のテストをサポートするヘルパーメソッド群

module AuthTestHelpers
  # テスト用ユーザーを作成する
  def create_test_user(attributes = {})
    default_attributes = {
      name: 'テストユーザー',
      email: 'test@example.com',
      password: 'password123',
      password_confirmation: 'password123'
    }
    
    User.create!(default_attributes.merge(attributes))
  end
  
  # テスト用のアクセストークンを生成する
  def generate_test_access_token(user_id, expiration = 24.hours)
    JsonWebToken.encode({ user_id: user_id }, expiration)
  end
  
  # テスト用のリフレッシュトークンとセッションIDを生成する
  def generate_test_refresh_token(user_id)
    JsonWebToken.generate_refresh_token(user_id)
  end
  
  # 認証ヘッダーを含むリクエストオプションを生成する
  def auth_headers(token)
    { 
      'Authorization' => "Bearer #{token}",
      'Accept' => 'application/json'
    }
  end
  
  # モックされたJWTトークンをセットアップする
  def mock_jwt_tokens
    # アクセストークン
    access_token = 'mock_access_token'
    allow(JsonWebToken).to receive(:encode).and_return(access_token)
    
    # リフレッシュトークン
    refresh_token = 'mock_refresh_token'
    session_id = 'mock_session_id'
    allow(JsonWebToken).to receive(:generate_refresh_token).and_return([refresh_token, session_id])
    
    [access_token, refresh_token, session_id]
  end
  
  # 認証済みユーザーとしてログインするヘルパー
  def login_as(user)
    access_token, refresh_token, session_id = mock_jwt_tokens
    
    # ユーザーにセッションIDを設定
    user.update(session_id: session_id)
    
    # コントローラレベルでcurrent_userを設定
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:authenticate_request!).and_return(true)
    
    # トークンを返す
    {
      user: user,
      access_token: access_token,
      refresh_token: refresh_token,
      session_id: session_id
    }
  end
  
  # リフレッシュトークンをCookieに設定するヘルパー
  def set_refresh_token_cookie(refresh_token)
    cookies[:refresh_token] = refresh_token
  end
  
  # 有効なトークンペイロードを生成する
  def valid_token_payload(user_id, token_type: 'access', session_id: nil, expiration: 24.hours)
    payload = {
      'user_id' => user_id,
      'iss' => JsonWebToken::ISSUER,
      'aud' => JsonWebToken::AUDIENCE,
      'iat' => Time.current.to_i,
      'nbf' => Time.current.to_i,
      'jti' => SecureRandom.uuid,
      'exp' => (Time.current + expiration).to_i
    }
    
    if token_type == 'refresh'
      payload['token_type'] = 'refresh'
      payload['session_id'] = session_id || SecureRandom.hex(16)
    end
    
    payload
  end
  
  # デコード時のモックを設定する
  def mock_jwt_decode(payload)
    allow(JsonWebToken).to receive(:decode).and_return(payload)
  end
  
  # テスト用の認証エラーレスポンスを検証する
  def expect_unauthorized_response(response)
    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body)).to have_key('error')
  end
  
  # リフレッシュトークンのCookieが正しく設定されているか検証する
  def expect_refresh_token_cookie(response, token)
    expect(response.cookies['refresh_token']).to eq(token)
    expect(response.cookies['refresh_token_secure']).to be true
    expect(response.cookies['refresh_token_http_only']).to be true
  end
  
  # サンプルのJWTトークンを返す（早期リターン用）
  def stub_jwt_encode(payload = {})
    default_payload = { user_id: 1 }
    combined_payload = default_payload.merge(payload)
    
    # JWTトークンを実際に生成（テスト用）
    header = { typ: 'JWT', alg: 'HS256' }
    encoded_header = Base64.strict_encode64(header.to_json)
    encoded_payload = Base64.strict_encode64(combined_payload.to_json)
    signature = 'test_signature'
    
    "#{encoded_header}.#{encoded_payload}.#{signature}"
  end
  
  # メタ認知: セキュリティ考慮点
  # 以下はテストヘルパーの使用例と考慮点に関するドキュメントです
  
  # 使用例:
  # RSpec.describe Api::V1::ResourcesController, type: :request do
  #   include AuthTestHelpers
  #
  #   let(:user) { create_test_user }
  #   let(:token) { generate_test_access_token(user.id) }
  #
  #   describe 'GET /api/v1/resources' do
  #     it '認証済みユーザーがリソースにアクセスできること' do
  #       get '/api/v1/resources', headers: auth_headers(token)
  #       expect(response).to have_http_status(:ok)
  #     end
  #   end
  # end
  
  # セキュリティ考慮点:
  # 1. テスト用トークンの使用: テスト環境でのみ使用し、本番環境では使わない
  # 2. テストデータ: センシティブなデータを実際のテストに含めない
  # 3. モックの適切な使用: セキュリティ関連のテストでは実際の処理もテストする
  # 4. 包括的なテスト: 正常系だけでなく異常系も十分にテストする
end

# RSpec設定でヘルパーを自動インクルード
RSpec.configure do |config|
  config.include AuthTestHelpers, type: :request
  config.include AuthTestHelpers, type: :controller
end 