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
    end

    context "with custom expiry time" do
      it "accepts an integer as exp" do
        exp = (now + 5.minutes).to_i
        token = described_class.encode(payload, exp)
        decoded_payload = JWT.decode(token, described_class::SECRET_KEY, true, {algorithm: described_class::ALGORITHM}).first
        expect(decoded_payload["exp"]).to eq(exp)
      end

      it "accepts a Time object as exp" do
        exp_time = now + 5.minutes
        token = described_class.encode(payload, exp_time)
        decoded_payload = JWT.decode(token, described_class::SECRET_KEY, true, {algorithm: described_class::ALGORITHM}).first
        expect(decoded_payload["exp"]).to eq(exp_time.to_i)
      end

      it "accepts a DateTime object as exp" do
        exp_datetime = (now + 5.minutes).to_datetime
        token = described_class.encode(payload, exp_datetime)
        decoded_payload = JWT.decode(token, described_class::SECRET_KEY, true, {algorithm: described_class::ALGORITHM}).first
        expect(decoded_payload["exp"]).to eq(exp_datetime.to_i)
      end

      it "handles nil expiry by using default expiry" do
        token = described_class.encode(payload, nil)
        decoded_payload = JWT.decode(token, described_class::SECRET_KEY, true, {algorithm: described_class::ALGORITHM}).first
        expect(decoded_payload).to have_key("exp")
        expect(Time.zone.at(decoded_payload["exp"])).to be > Time.zone.now
        expect(Time.zone.at(decoded_payload["exp"])).to be < Time.zone.now + described_class::TOKEN_EXPIRY + 10.seconds
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
