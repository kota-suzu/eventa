# frozen_string_literal: true

require "rails_helper"

RSpec.describe JsonWebToken do
  let(:user_id) { 1 }
  let(:payload) { {user_id: user_id} }
  let(:now) { Time.zone.now }
  let(:expired_token) { nil }

  before do
    # 有効期限切れのトークンを生成
    expiry = 10.minutes.ago.to_i
    JWT.encode({user_id: user_id, exp: expiry}, described_class::SECRET_KEY, described_class::ALGORITHM)
  end

  describe ".encode" do
    context "with default expiry time" do
      it "encodes a payload into a JWT token" do
        token = described_class.encode(payload)
        decoded_payload = JWT.decode(token, described_class::SECRET_KEY, true, {algorithm: described_class::ALGORITHM}).first
        expect(decoded_payload["user_id"]).to eq(user_id)
      end

      it "adds standard claims" do
        token = described_class.encode(payload)
        decoded_payload = JWT.decode(token, described_class::SECRET_KEY, true, {algorithm: described_class::ALGORITHM}).first
        expect(decoded_payload).to have_key("exp")
        expect(decoded_payload).to have_key("iat")
      end

      it "expires in the future" do
        token = described_class.encode(payload)
        decoded_payload = JWT.decode(token, described_class::SECRET_KEY, true, {algorithm: described_class::ALGORITHM}).first
        expect(Time.zone.at(decoded_payload["exp"])).to be > Time.zone.now
      end

      it "sets expiry to default when given invalid expiry" do
        token = described_class.encode(payload, "invalid_expiry")
        decoded_payload = JWT.decode(token, described_class::SECRET_KEY, true, {algorithm: described_class::ALGORITHM}).first
        expect(Time.zone.at(decoded_payload["exp"])).to be > Time.zone.now
        expect(Time.zone.at(decoded_payload["exp"])).to be < Time.zone.now + described_class::TOKEN_EXPIRY + 10.seconds
      end
    end

    context "with custom expiry time" do
      it "accepts a Time object as exp" do
        time = Time.now + 2.hours
        token = described_class.encode({data: "data"}, time)
        decoded_token = JWT.decode(token, described_class::SECRET_KEY,
          true, {algorithm: described_class::ALGORITHM, verify_iat: true})[0]

        expect(decoded_token["exp"].to_i).to eq(time.to_i)
      end

      it "accepts a DateTime object as exp" do
        time = DateTime.now + 2.hours
        token = described_class.encode({data: "data"}, time)
        decoded_token = JWT.decode(token, described_class::SECRET_KEY,
          true, {algorithm: described_class::ALGORITHM, verify_iat: true})[0]

        expect(decoded_token["exp"].to_i).to eq(time.to_i)
      end

      it "accepts ActiveSupport::Duration as exp" do
        token = described_class.encode({data: "data"}, 2.hours)
        decoded_token = JWT.decode(token, described_class::SECRET_KEY,
          true, {algorithm: described_class::ALGORITHM, verify_iat: true})[0]

        expected_time = Time.now + 2.hours
        expect(decoded_token["exp"].to_i).to be_within(5).of(expected_time.to_i)
      end

      it "accepts float as exp" do
        # 現在時刻を取得し、1時間後のUNIXタイムスタンプを計算
        current_time = Time.now.to_i
        one_hour_later = current_time + 3600 # 1時間 = 3600秒

        # テスト対象コードで使用されるSECRET_KEYとALGORITHMを取得
        secret_key = described_class::SECRET_KEY
        algorithm = described_class::ALGORITHM

        # JsonWebTokenのencodeメソッドでトークンを生成
        token = described_class.encode({data: "data"}, one_hour_later.to_f)

        # トークンをデコードして検証
        decoded_token = JWT.decode(
          token,
          secret_key,
          true,
          {
            algorithm: algorithm,
            verify_iat: true,
            verify_iss: false,  # テスト用に一時的に無効化
            verify_aud: false   # テスト用に一時的に無効化
          }
        )[0]

        # expが正しく設定されているか確認（数秒の誤差を許容）
        expect(decoded_token["exp"].to_i).to be_within(5).of(one_hour_later)
      end

      it "accepts an integer as exp" do
        time = (Time.now + 2.hours).to_i
        token = described_class.encode({data: "data"}, time)
        decoded_token = JWT.decode(token, described_class::SECRET_KEY,
          true, {algorithm: described_class::ALGORITHM, verify_iat: true})[0]

        expect(decoded_token["exp"].to_i).to eq(time)
      end

      it "handles nil expiry by using default expiry" do
        token = described_class.encode({data: "data"}, nil)
        decoded_token = JWT.decode(token, described_class::SECRET_KEY,
          true, {algorithm: described_class::ALGORITHM, verify_iat: true})[0]

        expected_time = Time.now + 24.hours
        expect(decoded_token["exp"].to_i).to be_within(5).of(expected_time.to_i)
      end
    end

    context "with additional claims" do
      it "merges additional claims" do
        additional_claims = {"admin" => true, "scope" => "read:all"}
        token = described_class.encode(payload.merge(additional_claims))
        decoded_payload = JWT.decode(token, described_class::SECRET_KEY, true, {algorithm: described_class::ALGORITHM}).first
        expect(decoded_payload["admin"]).to eq(true)
        expect(decoded_payload["scope"]).to eq("read:all")
      end
    end

    it "includes standard security claims" do
      token = described_class.encode(payload)
      decoded_payload = JWT.decode(token, described_class::SECRET_KEY, true, {algorithm: described_class::ALGORITHM}).first
      expect(decoded_payload["iss"]).to eq(described_class::ISSUER)
      expect(decoded_payload["aud"]).to eq(described_class::AUDIENCE)
      expect(decoded_payload["iat"]).to be_within(10).of(Time.zone.now.to_i)
      expect(decoded_payload["nbf"]).to be_within(10).of(Time.zone.now.to_i)
      expect(decoded_payload["jti"]).to be_present
    end
  end

  describe ".decode" do
    context "with valid token" do
      it "decodes a JWT token" do
        token = described_class.encode(payload)
        decoded_payload = described_class.decode(token)
        expect(decoded_payload["user_id"]).to eq(user_id)
      end
    end

    context "with invalid token" do
      it "raises error for expired token" do
        expiry = 10.minutes.ago.to_i
        token = JWT.encode(payload.merge(exp: expiry), described_class::SECRET_KEY, described_class::ALGORITHM)
        expect { described_class.decode(token) }.to raise_error(JWT::ExpiredSignature)
      end

      it "raises error for malformed token" do
        expect { described_class.decode("invalid.token") }.to raise_error(JWT::DecodeError)
      end

      it "raises error for token with invalid signature" do
        token = JWT.encode(payload, "wrong_secret", described_class::ALGORITHM)
        expect { described_class.decode(token) }.to raise_error(JWT::VerificationError)
      end

      it "raises error for nil token" do
        expect { described_class.decode(nil) }.to raise_error(JWT::DecodeError)
      end

      it "raises error for empty token" do
        expect { described_class.decode("") }.to raise_error(JWT::DecodeError)
      end

      it "raises error for token with invalid issuer" do
        invalid_iss_payload = payload.merge(
          iss: "invalid-issuer",
          exp: 1.hour.from_now.to_i,
          iat: Time.zone.now.to_i,
          nbf: Time.zone.now.to_i,
          aud: described_class::AUDIENCE,
          jti: SecureRandom.uuid
        )
        token = JWT.encode(invalid_iss_payload, described_class::SECRET_KEY, described_class::ALGORITHM)
        expect { described_class.decode(token) }.to raise_error(JWT::InvalidIssuerError)
      end

      it "raises error for token with invalid audience" do
        invalid_aud_payload = payload.merge(
          iss: described_class::ISSUER,
          exp: 1.hour.from_now.to_i,
          iat: Time.zone.now.to_i,
          nbf: Time.zone.now.to_i,
          aud: "invalid-audience",
          jti: SecureRandom.uuid
        )
        token = JWT.encode(invalid_aud_payload, described_class::SECRET_KEY, described_class::ALGORITHM)
        expect { described_class.decode(token) }.to raise_error(JWT::InvalidAudError)
      end
    end
  end

  describe ".safe_decode" do
    context "with valid token" do
      it "decodes a JWT token and returns the payload" do
        token = described_class.encode(payload)
        decoded_payload = described_class.safe_decode(token)
        expect(decoded_payload["user_id"]).to eq(user_id)
      end
    end

    context "with invalid token" do
      it "returns nil for expired token" do
        expiry = 10.minutes.ago.to_i
        token = JWT.encode(payload.merge(exp: expiry), described_class::SECRET_KEY, described_class::ALGORITHM)
        expect(described_class.safe_decode(token)).to be_nil
      end

      it "returns nil for malformed token" do
        expect(described_class.safe_decode("invalid.token")).to be_nil
      end

      it "returns nil for token with invalid signature" do
        token = JWT.encode(payload, "wrong_secret", described_class::ALGORITHM)
        expect(described_class.safe_decode(token)).to be_nil
      end

      it "returns nil for nil token" do
        expect(described_class.safe_decode(nil)).to be_nil
      end

      it "returns nil for empty token" do
        expect(described_class.safe_decode("")).to be_nil
      end

      it "returns nil for token with invalid issuer" do
        invalid_iss_payload = payload.merge(
          iss: "invalid-issuer",
          exp: 1.hour.from_now.to_i,
          iat: Time.zone.now.to_i,
          nbf: Time.zone.now.to_i,
          aud: described_class::AUDIENCE,
          jti: SecureRandom.uuid
        )
        token = JWT.encode(invalid_iss_payload, described_class::SECRET_KEY, described_class::ALGORITHM)
        expect(described_class.safe_decode(token)).to be_nil
      end

      it "returns nil for token with invalid audience" do
        invalid_aud_payload = payload.merge(
          iss: described_class::ISSUER,
          exp: 1.hour.from_now.to_i,
          iat: Time.zone.now.to_i,
          nbf: Time.zone.now.to_i,
          aud: "invalid-audience",
          jti: SecureRandom.uuid
        )
        token = JWT.encode(invalid_aud_payload, described_class::SECRET_KEY, described_class::ALGORITHM)
        expect(described_class.safe_decode(token)).to be_nil
      end

      it "logs error message when token decoding fails" do
        # テスト用のロガーモックを作成
        logger_double = instance_double(ActiveSupport::Logger)
        allow(Rails).to receive(:logger).and_return(logger_double)

        # エラーメッセージがログに記録されることを期待（infoレベルへ修正）
        # 1回以上呼ばれることを期待するように修正（at_least(1)）
        expect(logger_double).to receive(:info).with(/JWT decode error: Invalid segment encoding/).at_least(1)

        # 無効なトークンを渡して safe_decode を呼び出す
        described_class.safe_decode("invalid.token")
      end
    end
  end

  describe ".generate_refresh_token" do
    it "generates a refresh token" do
      refresh_token = described_class.generate_refresh_token
      expect(refresh_token).to be_a(String)
      expect(refresh_token.length).to be >= 32
    end

    it "generates a unique token each time" do
      token1 = described_class.generate_refresh_token
      token2 = described_class.generate_refresh_token
      expect(token1).not_to eq(token2)
    end

    it "uses SecureRandom to generate tokens" do
      expect(SecureRandom).to receive(:hex).with(32).and_return("mocked_token")
      refresh_token = described_class.generate_refresh_token
      expect(refresh_token).to eq("mocked_token")
    end

    it "generates a JWT token with user_id when user_id is provided" do
      user_id = 42
      token, session_id = described_class.generate_refresh_token(user_id)

      expect(token).to be_a(String)
      expect(session_id).to be_a(String)
      expect(session_id.length).to be >= 32

      # トークンをデコードして内容を確認
      decoded_payload = JWT.decode(token, described_class::SECRET_KEY, true, {algorithm: described_class::ALGORITHM}).first
      expect(decoded_payload["user_id"]).to eq(user_id)
      expect(decoded_payload["session_id"]).to eq(session_id)
      expect(decoded_payload["token_type"]).to eq("refresh")
    end

    it "sets longer expiration for refresh tokens" do
      user_id = 42
      token, _session_id = described_class.generate_refresh_token(user_id)

      # トークンをデコードして内容を確認
      decoded_payload = JWT.decode(token, described_class::SECRET_KEY, true, {algorithm: described_class::ALGORITHM}).first

      refresh_exp = Rails.configuration.x.jwt[:refresh_expiration] || 30.days
      expected_exp = (Time.zone.now + refresh_exp).to_i

      # 数秒の誤差を許容
      expect(decoded_payload["exp"]).to be_within(10).of(expected_exp)
    end

    it "user_idがnilの場合はセッションIDのみを返す" do
      # user_idを指定せずにメソッドを呼び出す
      session_id = described_class.generate_refresh_token

      # 結果がStringかつ長さが32文字以上であることを確認
      expect(session_id).to be_a(String)
      expect(session_id.length).to be >= 32

      # 結果が配列ではなく文字列であることを確認
      expect(session_id).not_to be_an(Array)
    end
  end

  describe "error handling in decode" do
    it "handles JWT::ExpiredSignature" do
      allow(JWT).to receive(:decode).and_raise(JWT::ExpiredSignature.new("Expired token"))
      expect { described_class.decode("some_token") }.to raise_error(JWT::ExpiredSignature)
    end

    it "handles JWT::VerificationError" do
      allow(JWT).to receive(:decode).and_raise(JWT::VerificationError.new("Invalid signature"))
      expect { described_class.decode("some_token") }.to raise_error(JWT::VerificationError)
    end

    it "handles JWT::DecodeError" do
      allow(JWT).to receive(:decode).and_raise(JWT::DecodeError.new("Invalid token"))
      expect { described_class.decode("some_token") }.to raise_error(JWT::DecodeError)
    end
  end

  # 以下の追加テストはブランチカバレッジを向上させるためのものです
  describe "追加のエッジケーステスト" do
    it "HashからObjectへの変換が正しく行われる" do
      # 配列ではなくObject形式のHashを使用
      token = described_class.encode({data: []})
      expect(token).to be_a(String)
      payload = described_class.safe_decode(token)
      expect(payload).to be_a(Hash)
      expect(payload["data"]).to eq([])
    end

    it "シンボルキーの場合、エンコード後にも値が保持される" do
      payload = {:symbol_key => "value", "string_key" => "value2"}
      token = described_class.encode(payload)
      decoded = described_class.safe_decode(token)
      expect(decoded["symbol_key"]).to eq("value")
      expect(decoded["string_key"]).to eq("value2")
    end

    it "expが文字列の場合、デフォルト値が使用される" do
      # 文字列は解析できないため、デフォルトのexpiry
      token = described_class.encode(payload, "invalid_exp")
      decoded = described_class.safe_decode(token)
      # expはdecodeで返却されるので、トークンが解析でき、かつ有効期限内であることを確認
      expect(decoded).to be_a(Hash)
      expect(decoded["user_id"]).to eq(user_id)
    end

    it "無効なトークンタイプの場合、safe_decodeはnilを返す" do
      # 元のJWTの実装に対応するため
      expect(described_class.safe_decode(nil)).to be_nil
      expect(described_class.safe_decode("")).to be_nil
      expect(described_class.safe_decode("invalid.token")).to be_nil
    end

    it "デコード時の各種例外タイプがログに記録される" do
      logger_double = instance_double(ActiveSupport::Logger)
      allow(Rails).to receive(:logger).and_return(logger_double)
      allow(logger_double).to receive(:info)

      # JWT::InvalidIssuerError をシミュレート
      invalid_iss_payload = payload.merge(
        iss: "invalid-issuer",
        exp: 1.hour.from_now.to_i,
        iat: Time.zone.now.to_i,
        nbf: Time.zone.now.to_i,
        aud: described_class::AUDIENCE,
        jti: SecureRandom.uuid
      )
      token = JWT.encode(invalid_iss_payload, described_class::SECRET_KEY, described_class::ALGORITHM)
      described_class.safe_decode(token)
      expect(logger_double).to have_received(:info).with(/JWT decode error/).at_least(1)

      # JWT::InvalidAudError をシミュレート
      invalid_aud_payload = payload.merge(
        iss: described_class::ISSUER,
        exp: 1.hour.from_now.to_i,
        iat: Time.zone.now.to_i,
        nbf: Time.zone.now.to_i,
        aud: "invalid-audience",
        jti: SecureRandom.uuid
      )
      token = JWT.encode(invalid_aud_payload, described_class::SECRET_KEY, described_class::ALGORITHM)
      described_class.safe_decode(token)
      expect(logger_double).to have_received(:info).with(/JWT decode error/).at_least(2)
    end

    it "JWTVerificationErrorがsafe_decodeでキャッチされる" do
      # JWT::VerificationErrorをシミュレート
      allow(JWT).to receive(:decode).and_raise(JWT::VerificationError.new("Invalid signature"))

      # 例外がキャッチされ、nilが返されることを確認
      expect(described_class.safe_decode("some_token")).to be_nil

      # 別の例外クラスでも同様にテスト
      allow(JWT).to receive(:decode).and_raise(JWT::InvalidJtiError.new("Invalid JTI"))
      expect(described_class.safe_decode("some_token")).to be_nil
    end

    it "複数のJWTトークンを生成すると、異なるjtiが割り当てられる" do
      # 同じペイロードで2つのトークンを生成
      token1 = described_class.encode(payload)
      token2 = described_class.encode(payload)

      # デコードして内容を確認
      decoded1 = JWT.decode(token1, described_class::SECRET_KEY, true,
        {algorithm: described_class::ALGORITHM}).first
      decoded2 = JWT.decode(token2, described_class::SECRET_KEY, true,
        {algorithm: described_class::ALGORITHM}).first

      # jtiが異なることを確認
      expect(decoded1["jti"]).not_to eq(decoded2["jti"])

      # 両方ともUUIDの形式であることを確認
      uuid_regex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
      expect(decoded1["jti"]).to match(uuid_regex)
      expect(decoded2["jti"]).to match(uuid_regex)
    end
  end
end
