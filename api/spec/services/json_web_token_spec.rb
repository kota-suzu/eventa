# frozen_string_literal: true

require "rails_helper"

RSpec.describe JsonWebToken do
  let(:user_id) { 123 }
  let(:payload) { { user_id: user_id } }
  let(:now) { Time.current }

  describe ".encode" do
    it "encodes a payload into a JWT token" do
      token = described_class.encode(payload)
      expect(token).to be_a(String)
      expect(token.split(".").length).to eq(3) # ヘッダー、ペイロード、署名の3部構成
    end

    it "adds standard JWT claims to the payload" do
      travel_to now do
        token = described_class.encode(payload)
        decoded_payload = JWT.decode(token, described_class::SECRET, true, { algorithm: "HS256" }).first
        
        expect(decoded_payload["iss"]).to eq(described_class::ISSUER)
        expect(decoded_payload["aud"]).to eq(described_class::AUDIENCE)
        expect(decoded_payload["iat"]).to eq(now.to_i)
        expect(decoded_payload["nbf"]).to eq(now.to_i)
        expect(decoded_payload["jti"]).to be_present
        expect(decoded_payload["exp"]).to eq((now + described_class::DEFAULT_EXP).to_i)
        expect(decoded_payload["user_id"]).to eq(user_id)
      end
    end

    context "with custom expiration" do
      it "accepts ActiveSupport::Duration" do
        travel_to now do
          token = described_class.encode(payload, 2.hours)
          decoded_payload = JWT.decode(token, described_class::SECRET, true, { algorithm: "HS256" }).first
          expect(decoded_payload["exp"]).to eq((now + 2.hours).to_i)
        end
      end

      it "accepts Time object" do
        custom_time = 3.days.from_now
        token = described_class.encode(payload, custom_time)
        decoded_payload = JWT.decode(token, described_class::SECRET, true, { algorithm: "HS256" }).first
        expect(decoded_payload["exp"]).to eq(custom_time.to_i)
      end

      it "accepts numeric seconds" do
        travel_to now do
          token = described_class.encode(payload, 1800) # 30分
          decoded_payload = JWT.decode(token, described_class::SECRET, true, { algorithm: "HS256" }).first
          expect(decoded_payload["exp"]).to eq((now + 1800).to_i)
        end
      end
    end
  end

  describe ".decode" do
    context "with valid token" do
      it "decodes a token and returns the payload" do
        token = described_class.encode(payload)
        decoded = described_class.decode(token)
        expect(decoded).to include("user_id" => user_id)
      end
    end

    context "with invalid token" do
      it "returns nil for expired token" do
        expired_token = nil
        
        # 期限切れトークンを作成するために、expを現在時刻より前に設定
        custom_payload = payload.merge(
          exp: (Time.current - 10.seconds).to_i,  # 過去の有効期限
          iat: (Time.current - 1.hour).to_i,      # 過去の発行時刻
          nbf: (Time.current - 1.hour).to_i       # 過去の有効開始時刻
        )
        
        # JWTを直接使って期限切れトークンを作成
        expired_token = JWT.encode(
          custom_payload,
          described_class::SECRET,
          'HS256'
        )
        
        decoded = described_class.decode(expired_token)
        expect(decoded).to be_nil
      end

      it "returns nil for malformed token" do
        decoded = described_class.decode("invalid.token.format")
        expect(decoded).to be_nil
      end

      it "returns nil for token with invalid signature" do
        token = described_class.encode(payload)
        parts = token.split(".")
        parts[2] = "invalid_signature" # 署名部分を改ざん
        tampered_token = parts.join(".")
        
        decoded = described_class.decode(tampered_token)
        expect(decoded).to be_nil
      end

      it "returns nil when token is nil or empty" do
        expect(described_class.decode(nil)).to be_nil
        expect(described_class.decode("")).to be_nil
      end
    end
  end

  describe ".generate_refresh_token" do
    it "generates a refresh token with correct payload" do
      token, session_id = described_class.generate_refresh_token(user_id)
      
      expect(token).to be_a(String)
      expect(session_id).to be_a(String)
      expect(session_id.length).to eq(32) # 16バイトのhex文字列なので32文字
      
      decoded = JWT.decode(token, described_class::SECRET, true, { algorithm: "HS256" }).first
      expect(decoded["user_id"]).to eq(user_id)
      expect(decoded["session_id"]).to eq(session_id)
      expect(decoded["token_type"]).to eq("refresh")
    end
  end
end
