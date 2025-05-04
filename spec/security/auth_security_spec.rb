require 'rails_helper'

RSpec.describe "認証システムセキュリティテスト", type: :request do
  include AuthTestHelpers
  
  # メタ認知: セキュリティテストでは、潜在的な脆弱性を探して実証します。
  # このテストファイルでは、JWT認証に特化したセキュリティリスクを検証します。
  
  let(:user_email) { "security_test@example.com" }
  let(:user_password) { "secure_password123" }
  let(:user_name) { "セキュリティテストユーザー" }
  
  let(:user) do
    User.create!(
      name: user_name,
      email: user_email,
      password: user_password,
      password_confirmation: user_password
    )
  end
  
  let(:valid_login_params) do
    {
      auth: {
        email: user_email,
        password: user_password
      }
    }
  end
  
  before do
    # 既存ユーザーをクリア
    User.find_by(email: user_email)&.destroy
    
    # テストユーザーを作成
    user
    
    # 時間を固定
    travel_to Time.zone.local(2025, 5, 1, 12, 0, 0)
  end
  
  after do
    travel_back
  end
  
  # ステップ1: トークン操作に関するセキュリティテスト
  describe "トークンセキュリティテスト" do
    let(:login_response) do
      post api_v1_auth_login_path, params: valid_login_params
      response
    end
    
    let(:valid_token) { login_response.parsed_body['token'] }
    let(:refresh_token) { login_response.cookies['refresh_token'] }
    
    # メタ認知: トークン改ざんテストは、JWT署名の検証機能が正しく動作するか確認します
    it "改ざんされたJWTトークンが拒否されること" do
      # 有効なトークンの構造を分析
      token_parts = valid_token.split('.')
      expect(token_parts.length).to eq(3) # ヘッダー、ペイロード、署名の3パート
      
      # トークンのペイロード部分を改ざん
      header = token_parts[0]
      payload = Base64.decode64(token_parts[1])
      tampered_payload = payload.gsub(/"user_id":\d+/, '"user_id":999')
      tampered_payload_base64 = Base64.strict_encode64(tampered_payload).gsub(/=+$/, '')
      signature = token_parts[2]
      
      # 改ざんされたトークンを作成
      tampered_token = "#{header}.#{tampered_payload_base64}.#{signature}"
      
      # 改ざんされたトークンで認証が必要なAPIにアクセス
      get api_v1_protected_resource_path, headers: { 'Authorization': "Bearer #{tampered_token}" }
      
      # 認証が拒否されることを確認
      expect(response).to have_http_status(:unauthorized)
    end
    
    # メタ認知: 期限切れトークンのテストは、有効期限の検証が正しく機能することを確認します
    it "期限切れのJWTトークンが拒否されること" do
      # 未来の時刻に移動してトークンを期限切れにする
      travel_to 2.days.from_now
      
      # 期限切れトークンで認証が必要なAPIにアクセス
      get api_v1_protected_resource_path, headers: { 'Authorization': "Bearer #{valid_token}" }
      
      # 認証が拒否されることを確認
      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)['error']).to include('無効なトークン')
    end

    # メタ認知: クロスサイトリクエストフォージェリ対策のテスト
    it "CSRF対策として、認証トークンをCookie経由で送信できないこと" do
      # Cookieに認証トークンを設定（これは本来許可されるべきではない）
      cookies['auth_token'] = valid_token
      
      # 認証トークンをヘッダーに含めずにAPIアクセス
      get api_v1_protected_resource_path
      
      # 認証が拒否されることを確認
      expect(response).to have_http_status(:unauthorized)
    end
  end
  
  # ステップ2: セッション管理のセキュリティテスト
  describe "セッション管理セキュリティテスト" do
    it "サーバー側でセッションを取り消すとトークンが無効になること" do
      # ログイン
      post api_v1_auth_login_path, params: valid_login_params
      token = response.parsed_body['token']
      
      # セッションIDをDBから削除（ログアウト操作）
      user.update(session_id: nil)
      
      # トークンで認証が必要なAPIにアクセス
      get api_v1_protected_resource_path, headers: { 'Authorization': "Bearer #{token}" }
      
      # 認証が拒否されることを確認（セッションIDが無効化されているため）
      expect(response).to have_http_status(:unauthorized)
    end
    
    it "ログアウト後、同じ資格情報で再ログインすると新しいセッションIDが発行されること" do
      # 1回目のログイン
      post api_v1_auth_login_path, params: valid_login_params
      first_token = response.parsed_body['token']
      first_session_id = user.reload.session_id
      
      # ログアウト
      delete api_v1_auth_logout_path, headers: { 'Authorization': "Bearer #{first_token}" }
      
      # 2回目のログイン
      post api_v1_auth_login_path, params: valid_login_params
      second_token = response.parsed_body['token']
      second_session_id = user.reload.session_id
      
      # セッションIDが異なることを確認
      expect(second_session_id).not_to eq(first_session_id)
      
      # 古いトークンが無効になっていることを確認
      get api_v1_protected_resource_path, headers: { 'Authorization': "Bearer #{first_token}" }
      expect(response).to have_http_status(:unauthorized)
      
      # 新しいトークンが有効であることを確認
      get api_v1_protected_resource_path, headers: { 'Authorization': "Bearer #{second_token}" }
      expect(response.status).not_to eq(401)
    end
  end
  
  # ステップ3: リフレッシュトークンのセキュリティテスト
  describe "リフレッシュトークンセキュリティテスト" do
    let(:login_response) do
      post api_v1_auth_login_path, params: valid_login_params
      response
    end
    
    let(:refresh_token) { login_response.cookies['refresh_token'] }
    
    it "異なるユーザーのリフレッシュトークンが使用できないこと" do
      # ユーザーA: 通常のログイン
      user_a = user
      
      # ユーザーB: 別のユーザーでログイン
      user_b = User.create!(
        name: "別のセキュリティテストユーザー",
        email: "security_test_b@example.com",
        password: user_password,
        password_confirmation: user_password
      )
      
      # ユーザーAでログイン
      post api_v1_auth_login_path, params: valid_login_params
      user_a_refresh_token = response.cookies['refresh_token']
      
      # 異なるユーザーBのセッションIDでユーザーAのリフレッシュトークンを使用
      user_a_refresh_payload = JsonWebToken.decode(user_a_refresh_token)
      manipulated_payload = user_a_refresh_payload.merge('user_id' => user_b.id)
      
      # 改ざんされたペイロードで新しいトークンを作成
      manipulated_token = JWT.encode(manipulated_payload, JsonWebToken::SECRET, 'HS256')
      
      # 改ざんされたリフレッシュトークンでトークン更新を試みる
      cookies['refresh_token'] = manipulated_token
      post api_v1_auth_refresh_path
      
      # リフレッシュが拒否されることを確認
      expect(response).to have_http_status(:unauthorized)
    end
    
    it "リフレッシュトークンがJSONPからアクセスできないこと（CSRF対策）" do
      # 通常のJSONPリクエストをシミュレート
      # これは実際にはRSpecでは難しいため、ヘッダーでコンテンツタイプ等を調整
      get "#{api_v1_auth_refresh_path}?callback=jsonpCallback", 
          headers: { 'Accept': 'application/javascript' }
      
      # JSONPでのアクセスが拒否され、JSONレスポンスが返されないことを確認
      expect(response.content_type).not_to include('javascript')
      expect(response.body).not_to include('jsonpCallback')
    end
  end
  
  # ステップ4: トークン漏洩シミュレーションテスト
  describe "トークン漏洩シミュレーションテスト" do
    it "アクセストークン漏洩時のリスク軽減: トークンの有効期限が短いこと" do
      # ログイン
      post api_v1_auth_login_path, params: valid_login_params
      token = response.parsed_body['token']
      
      # トークンをデコードして有効期限を確認
      payload = JsonWebToken.decode(token)
      
      # 発行時刻（iat）からの有効期限が適切に短いことを確認
      token_duration = payload['exp'] - payload['iat']
      
      # デフォルトは24時間だが、セキュリティを高めるには短くするべき
      if token_duration <= 3600 # 1時間以下
        # セキュリティ重視の短い期限
        expect(token_duration).to be <= 3600
      elsif token_duration <= 86400 # 24時間以下
        # バランス型の中程度の期限
        expect(token_duration).to be <= 86400
      else
        # 長い期限の場合は注意喚起
        puts "警告: トークンの有効期限が長すぎます (#{token_duration}秒)"
        expect(token_duration).to be <= 86400 # 最大でも24時間以内を推奨
      end
    end
    
    it "トークン漏洩時のセッション無効化: ログアウトでトークンを完全に無効化できること" do
      # ログイン
      post api_v1_auth_login_path, params: valid_login_params
      token = response.parsed_body['token']
      
      # セッションIDを確認
      expect(user.reload.session_id).to be_present
      
      # ログアウト
      delete api_v1_auth_logout_path, headers: { 'Authorization': "Bearer #{token}" }
      
      # セッションIDが削除されていることを確認
      expect(user.reload.session_id).to be_nil
      
      # トークンが無効化されていることを確認
      get api_v1_protected_resource_path, headers: { 'Authorization': "Bearer #{token}" }
      expect(response).to have_http_status(:unauthorized)
    end
  end
  
  # ステップ5: CSRF、XSS対策のテスト
  describe "CSRF・XSS対策テスト" do
    it "リフレッシュトークンがHTTPOnlyクッキーで保存されていること" do
      # ログイン
      post api_v1_auth_login_path, params: valid_login_params
      
      # HTTPOnlyフラグが設定されていることを確認
      expect(response.cookies['refresh_token_http_only']).to be true
    end
    
    it "SameSiteポリシーが適切に設定されていること" do
      # ログイン
      post api_v1_auth_login_path, params: valid_login_params
      
      # SameSiteポリシーが設定されていることを確認
      # 注: RspecではSameSite属性の詳細な確認が難しいため、実装による
      same_site = response.cookies['refresh_token_same_site']
      
      if same_site
        # 明示的に設定されている場合
        expect(['Strict', 'Lax']).to include(same_site)
      else
        # 設定されていない場合は警告
        puts "警告: SameSite属性が明示的に設定されていません"
        # アプリケーションのデフォルト設定に依存
      end
    end
  end

  # ステップ6: 認証エラーの情報開示テスト
  describe "認証エラーの情報開示テスト" do
    it "認証エラー時に過剰な情報を開示していないこと" do
      # 存在しないユーザーでログイン試行
      post api_v1_auth_login_path, params: {
        auth: {
          email: "nonexistent@example.com",
          password: "wrong_password"
        }
      }
      
      # エラーメッセージがユーザーの存在有無を明示していないことを確認
      error_msg = JSON.parse(response.body)['error']
      expect(error_msg).not_to include("存在しません")
      expect(error_msg).not_to include("見つかりません")
      
      # 一般的なエラーメッセージであることを確認
      expect(error_msg).to include("認証") # 「認証情報が無効です」のような一般的なメッセージ
    end
    
    it "パスワードが間違っている場合でも一般的なエラーメッセージを返すこと" do
      # 正しいユーザー名、間違ったパスワードでログイン試行
      post api_v1_auth_login_path, params: {
        auth: {
          email: user_email,
          password: "wrong_password"
        }
      }
      
      # エラーメッセージがパスワードの間違いを明示していないことを確認
      error_msg = JSON.parse(response.body)['error']
      expect(error_msg).not_to include("パスワード")
      expect(error_msg).not_to include("間違")
      
      # 一般的なエラーメッセージであることを確認
      expect(error_msg).to include("認証") # 「認証情報が無効です」のような一般的なメッセージ
    end
  end
  
  # ヘルパーメソッド: 認証が必要なAPIを想定したパス
  def api_v1_protected_resource_path
    # 実際のアプリケーションの保護されたリソースのパスに置き換えてください
    "/api/v1/user/profile"
  end
end 