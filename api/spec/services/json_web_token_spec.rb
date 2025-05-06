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
        decoded_token = JWT.decode(token, Rails.application.credentials.secret_key_base,
          true, {algorithm: "HS256", verify_iat: true})[0]

        expect(decoded_token["exp"].to_i).to eq(time.to_i)
      end

      it "accepts a DateTime object as exp" do
        time = DateTime.now + 2.hours
        token = described_class.encode({data: "data"}, time)
        decoded_token = JWT.decode(token, Rails.application.credentials.secret_key_base,
          true, {algorithm: "HS256", verify_iat: true})[0]

        expect(decoded_token["exp"].to_i).to eq(time.to_i)
      end

      it "accepts ActiveSupport::Duration as exp" do
        token = described_class.encode({data: "data"}, 2.hours)
        decoded_token = JWT.decode(token, Rails.application.credentials.secret_key_base,
          true, {algorithm: "HS256", verify_iat: true})[0]

        expected_time = Time.now + 2.hours
        expect(decoded_token["exp"].to_i).to be_within(5).of(expected_time.to_i)
      end

      it "accepts float as exp" do
        # 現在時刻を取得し、1時間後のUNIXタイムスタンプを計算
        current_time = Time.now.to_i
        one_hour_later = current_time + 3600 # 1時間 = 3600秒

        # テスト対象コードで使用されるSECRET_KEYとALGORITHMを取得
        secret_key = Rails.application.credentials.secret_key_base
        algorithm = "HS256"

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
        decoded_token = JWT.decode(token, Rails.application.credentials.secret_key_base,
          true, {algorithm: "HS256", verify_iat: true})[0]

        expect(decoded_token["exp"].to_i).to eq(time)
      end

      it "handles nil expiry by using default expiry" do
        token = described_class.encode({data: "data"}, nil)
        decoded_token = JWT.decode(token, Rails.application.credentials.secret_key_base,
          true, {algorithm: "HS256", verify_iat: true})[0]

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
end
