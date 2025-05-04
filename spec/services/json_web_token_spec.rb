require 'rails_helper'

RSpec.describe JsonWebToken do
  # テスト時のシークレットキーの状態を確認
  context 'メタテスト - 設定の検証' do
    it 'シークレットキーが設定されていること' do
      expect(JsonWebToken::SECRET).not_to be_nil
      expect(JsonWebToken::SECRET).not_to be_empty
    end

    it 'デフォルト有効期限が設定されていること' do
      expect(JsonWebToken::DEFAULT_EXP).not_to be_nil
      expect(JsonWebToken::DEFAULT_EXP).to be_a(ActiveSupport::Duration)
    end

    it '環境に応じた発行者（ISSUER）が設定されていること' do
      expect(JsonWebToken::ISSUER).to include(Rails.env)
    end
  end

  describe '.encode' do
    let(:user_id) { 123 }
    let(:base_payload) { { user_id: user_id } }
    let(:test_time) { Time.utc(2025, 5, 1, 12, 0, 0) }

    before do
      # Time.currentをスタブ化して一定の時間を返すようにする
      allow(Time).to receive(:current).and_return(test_time)
    end

    it 'JWTフォーマットの有効なトークンを生成する' do
      token = JsonWebToken.encode(base_payload)
      
      # トークンは文字列であること
      expect(token).to be_a(String)
      
      # トークンはヘッダー.ペイロード.署名の形式になっていること
      expect(token.split('.')).to have(3).items
    end
    
    it '標準的なセキュリティクレームを含める' do
      token = JsonWebToken.encode(base_payload)
      decoded = JWT.decode(token, JsonWebToken::SECRET, true, { algorithm: 'HS256' })[0]
      
      # 必須クレームを検証
      expect(decoded).to include('iss', 'aud', 'iat', 'nbf', 'jti', 'exp')
      expect(decoded['iss']).to eq(JsonWebToken::ISSUER)
      expect(decoded['aud']).to eq(JsonWebToken::AUDIENCE)
      expect(decoded['iat']).to eq(test_time.to_i)
      expect(decoded['nbf']).to eq(test_time.to_i)
      expect(decoded['jti']).to match(/^[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}$/) # UUID形式
      
      # 有効期限が正しく設定されていること（デフォルト24時間）
      expected_exp = (test_time + JsonWebToken::DEFAULT_EXP).to_i
      expect(decoded['exp']).to eq(expected_exp)
    end
    
    it '元のペイロードの値を保持する' do
      custom_payload = { user_id: user_id, role: 'admin', email: 'test@example.com' }
      token = JsonWebToken.encode(custom_payload)
      decoded = JWT.decode(token, JsonWebToken::SECRET, true, { algorithm: 'HS256' })[0]
      
      # 元のデータが保持されていること
      expect(decoded['user_id']).to eq(user_id)
      expect(decoded['role']).to eq('admin')
      expect(decoded['email']).to eq('test@example.com')
    end
    
    it '元のペイロードを変更しない（副作用がない）' do
      original_payload = base_payload.dup
      JsonWebToken.encode(base_payload)
      
      # 元のペイロードは変更されていないこと
      expect(base_payload).to eq(original_payload)
    end
    
    it 'カスタム有効期限を設定できる' do
      custom_exp = 1.hour
      token = JsonWebToken.encode(base_payload, custom_exp)
      decoded = JWT.decode(token, JsonWebToken::SECRET, true, { algorithm: 'HS256' })[0]
      
      # カスタム有効期限が適用されていること
      expected_exp = (test_time + custom_exp).to_i
      expect(decoded['exp']).to eq(expected_exp)
    end
    
    it '負の有効期限を使用して過去の日時を設定できる（テスト用途）' do
      past_exp = -1.hour
      token = JsonWebToken.encode(base_payload, past_exp)
      decoded = JWT.decode(token, JsonWebToken::SECRET, false, { algorithm: 'HS256' })[0] # 検証せずにデコード
      
      # 過去の有効期限が適用されていること
      expected_exp = (test_time + past_exp).to_i
      expect(decoded['exp']).to eq(expected_exp)
    end
  end

  describe '.decode' do
    let(:user_id) { 123 }
    let(:base_payload) { { user_id: user_id } }
    let(:test_time) { Time.utc(2025, 5, 1, 12, 0, 0) }

    before do
      allow(Time).to receive(:current).and_return(test_time)
      allow(Rails.logger).to receive(:error) # ログ出力をスタブ化
    end

    it '有効なトークンを正しくデコードする' do
      token = JsonWebToken.encode(base_payload)
      decoded = JsonWebToken.decode(token)
      
      expect(decoded).to include('user_id')
      expect(decoded['user_id']).to eq(user_id)
      expect(decoded['iss']).to eq(JsonWebToken::ISSUER)
      expect(decoded['aud']).to eq(JsonWebToken::AUDIENCE)
    end
    
    it '不正な形式のトークンに対してnilを返す' do
      result = JsonWebToken.decode('invalid.token.string')
      expect(result).to be_nil
      expect(Rails.logger).to have_received(:error).with(/JWT decode error: JWT::DecodeError/)
    end
    
    it '有効期限切れのトークンに対してnilを返す' do
      expired_token = JsonWebToken.encode(base_payload, -1.hour)
      result = JsonWebToken.decode(expired_token)
      
      expect(result).to be_nil
      expect(Rails.logger).to have_received(:error).with(/JWT decode error: JWT::ExpiredSignature/)
    end
    
    it '不正な署名のトークンに対してnilを返す' do
      # 有効なトークンを生成して署名部分を改変
      valid_token = JsonWebToken.encode(base_payload)
      parts = valid_token.split('.')
      invalid_token = "#{parts[0]}.#{parts[1]}.invalid_signature"
      
      result = JsonWebToken.decode(invalid_token)
      
      expect(result).to be_nil
      expect(Rails.logger).to have_received(:error).with(/JWT decode error: JWT::VerificationError/)
    end
    
    it '不正な発行者のトークンに対してnilを返す' do
      # 独自のトークンを作成し、issクレームを変更
      invalid_iss_payload = base_payload.merge(
        iss: 'invalid-issuer',
        aud: JsonWebToken::AUDIENCE,
        iat: test_time.to_i,
        exp: (test_time + 1.hour).to_i
      )
      invalid_token = JWT.encode(invalid_iss_payload, JsonWebToken::SECRET, 'HS256')
      
      result = JsonWebToken.decode(invalid_token)
      
      expect(result).to be_nil
      expect(Rails.logger).to have_received(:error).with(/JWT decode error: JWT::InvalidIssuerError/)
    end
    
    it '不正な対象者のトークンに対してnilを返す' do
      # 独自のトークンを作成し、audクレームを変更
      invalid_aud_payload = base_payload.merge(
        iss: JsonWebToken::ISSUER,
        aud: 'invalid-audience',
        iat: test_time.to_i,
        exp: (test_time + 1.hour).to_i
      )
      invalid_token = JWT.encode(invalid_aud_payload, JsonWebToken::SECRET, 'HS256')
      
      result = JsonWebToken.decode(invalid_token)
      
      expect(result).to be_nil
      expect(Rails.logger).to have_received(:error).with(/JWT decode error: JWT::InvalidAudError/)
    end
    
    context 'leeway（時間ずれ許容）のテスト' do
      let(:nbf_future) { (test_time + 25.seconds).to_i } # 現在より25秒後
      
      it 'leeway時間内（30秒以内）の未来のnbfは許容する' do
        # 現在より25秒後を有効開始時間とする（leeway 30秒なので有効）
        future_payload = base_payload.merge(
          iss: JsonWebToken::ISSUER,
          aud: JsonWebToken::AUDIENCE,
          iat: test_time.to_i,
          nbf: nbf_future,
          exp: (test_time + 1.hour).to_i
        )
        token = JWT.encode(future_payload, JsonWebToken::SECRET, 'HS256')
        
        result = JsonWebToken.decode(token)
        
        expect(result).not_to be_nil
        expect(result['user_id']).to eq(user_id)
      end
      
      it 'leeway時間外（30秒以上）の未来のnbfは拒否する' do
        # 現在より40秒後を有効開始時間とする（leeway 30秒なので無効）
        far_future_payload = base_payload.merge(
          iss: JsonWebToken::ISSUER,
          aud: JsonWebToken::AUDIENCE,
          iat: test_time.to_i,
          nbf: (test_time + 40.seconds).to_i,
          exp: (test_time + 1.hour).to_i
        )
        token = JWT.encode(far_future_payload, JsonWebToken::SECRET, 'HS256')
        
        result = JsonWebToken.decode(token)
        
        expect(result).to be_nil
        expect(Rails.logger).to have_received(:error).with(/JWT decode error: JWT::ImmatureSignature/)
      end
    end
  end

  describe '.generate_refresh_token' do
    let(:user_id) { 456 }
    let(:test_time) { Time.utc(2025, 5, 1, 12, 0, 0) }
    let(:refresh_exp) { 30.days }

    before do
      allow(Time).to receive(:current).and_return(test_time)
      allow(Rails.configuration.x.jwt).to receive(:[]).with(:refresh_expiration).and_return(refresh_exp)
      allow(SecureRandom).to receive(:hex).with(16).and_return('0123456789abcdef0123456789abcdef')
      allow(SecureRandom).to receive(:uuid).and_return('aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee')
    end

    it 'リフレッシュトークンとセッションIDを返す' do
      token, session_id = JsonWebToken.generate_refresh_token(user_id)
      
      expect(token).to be_a(String)
      expect(session_id).to eq('0123456789abcdef0123456789abcdef')
    end
    
    it 'リフレッシュトークンはJWT形式である' do
      token, _ = JsonWebToken.generate_refresh_token(user_id)
      expect(token.split('.')).to have(3).items
    end
    
    it 'リフレッシュトークンは必要な属性を含む' do
      token, session_id = JsonWebToken.generate_refresh_token(user_id)
      decoded = JWT.decode(token, JsonWebToken::SECRET, true, { algorithm: 'HS256' })[0]
      
      # 固有属性の検証
      expect(decoded['user_id']).to eq(user_id)
      expect(decoded['session_id']).to eq(session_id)
      expect(decoded['token_type']).to eq('refresh')
      
      # JWT標準クレームの検証
      expect(decoded['iss']).to eq(JsonWebToken::ISSUER)
      expect(decoded['aud']).to eq(JsonWebToken::AUDIENCE)
      expect(decoded['jti']).to eq('aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee')
    end
    
    it 'リフレッシュトークンの有効期限が正しく設定されている' do
      token, _ = JsonWebToken.generate_refresh_token(user_id)
      decoded = JWT.decode(token, JsonWebToken::SECRET, true, { algorithm: 'HS256' })[0]
      
      expected_exp = (test_time + refresh_exp).to_i
      expect(decoded['exp']).to eq(expected_exp)
    end
    
    it 'リフレッシュトークンの設定が取得できない場合、デフォルト値を使用する' do
      # 設定から値が取得できないケースをシミュレート
      allow(Rails.configuration.x.jwt).to receive(:[]).with(:refresh_expiration).and_return(nil)
      
      token, _ = JsonWebToken.generate_refresh_token(user_id)
      decoded = JWT.decode(token, JsonWebToken::SECRET, true, { algorithm: 'HS256' })[0]
      
      # デフォルト30日が適用されること
      expected_exp = (test_time + 30.days).to_i
      expect(decoded['exp']).to eq(expected_exp)
    end
  end
end 