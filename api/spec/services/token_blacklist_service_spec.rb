# frozen_string_literal: true

require "rails_helper"

RSpec.describe TokenBlacklistService do
  let(:user) { create(:user) }
  let(:token) { JsonWebToken.encode({user_id: user.id}) }
  let(:refresh_token) { JsonWebToken.generate_refresh_token(user.id)[0] }
  let(:redis_instance) { instance_double(Redis) }

  before do
    allow(Redis).to receive(:new).and_return(redis_instance)
  end

  describe ".add" do
    it "有効なトークンをブラックリストに追加する" do
      payload = JsonWebToken.decode(token)
      jti = payload["jti"]
      payload["exp"]
      Time.now.to_i

      expect(JsonWebToken).to receive(:safe_decode).with(token).and_return(payload)
      expect(redis_instance).to receive(:setex).with(
        "blacklist:token:#{jti}",
        kind_of(Numeric),
        kind_of(String)
      ).and_return("OK")

      result = described_class.add(token, "logout")
      expect(result).to be true
    end

    it "すでに期限切れのトークンの場合はtrueを返す" do
      expired_payload = {
        "user_id" => user.id,
        "jti" => SecureRandom.uuid,
        "exp" => 1.hour.ago.to_i # 期限切れ
      }

      expect(JsonWebToken).to receive(:safe_decode).with(token).and_return(expired_payload)

      result = described_class.add(token)
      expect(result).to be true
      # すでに期限切れなのでRedisに保存されない
      expect(redis_instance).not_to receive(:setex)
    end

    it "無効なトークンの場合はfalseを返す" do
      expect(JsonWebToken).to receive(:safe_decode).with("invalid_token").and_return(nil)

      result = described_class.add("invalid_token")
      expect(result).to be false
    end

    it "JTIがないトークンの場合はfalseを返す" do
      payload_without_jti = {
        "user_id" => user.id,
        "exp" => 1.hour.from_now.to_i
        # jtiがない
      }

      expect(JsonWebToken).to receive(:safe_decode).with(token).and_return(payload_without_jti)

      result = described_class.add(token)
      expect(result).to be false
    end

    it "Redisエラー時にはfalseを返す" do
      payload = JsonWebToken.decode(token)

      expect(JsonWebToken).to receive(:safe_decode).with(token).and_return(payload)
      expect(redis_instance).to receive(:setex).and_raise(Redis::CannotConnectError)
      expect(Rails.logger).to receive(:error).with(/Failed to add token to blacklist/)

      result = described_class.add(token)
      expect(result).to be false
    end
  end

  describe ".blacklisted?" do
    it "ブラックリストにあるトークンの場合はtrueを返す" do
      payload = JsonWebToken.decode(token)
      jti = payload["jti"]

      expect(JsonWebToken).to receive(:safe_decode).with(token).and_return(payload)
      expect(redis_instance).to receive(:exists?).with("blacklist:token:#{jti}").and_return(true)

      result = described_class.blacklisted?(token)
      expect(result).to be true
    end

    it "ブラックリストにないトークンの場合はfalseを返す" do
      payload = JsonWebToken.decode(token)
      jti = payload["jti"]

      expect(JsonWebToken).to receive(:safe_decode).with(token).and_return(payload)
      expect(redis_instance).to receive(:exists?).with("blacklist:token:#{jti}").and_return(false)

      result = described_class.blacklisted?(token)
      expect(result).to be false
    end

    it "無効なトークンの場合はtrueを返す" do
      expect(JsonWebToken).to receive(:safe_decode).with("invalid_token").and_return(nil)

      result = described_class.blacklisted?("invalid_token")
      expect(result).to be true
    end

    it "JTIがないトークンの場合はtrueを返す" do
      payload_without_jti = {
        "user_id" => user.id,
        "exp" => 1.hour.from_now.to_i
        # jtiがない
      }

      expect(JsonWebToken).to receive(:safe_decode).with(token).and_return(payload_without_jti)

      result = described_class.blacklisted?(token)
      expect(result).to be true
    end

    it "Redisエラー時にはtrueを返す" do
      payload = JsonWebToken.decode(token)

      expect(JsonWebToken).to receive(:safe_decode).with(token).and_return(payload)
      expect(redis_instance).to receive(:exists?).and_raise(Redis::CannotConnectError)
      expect(Rails.logger).to receive(:error).with(/Failed to check token in blacklist/)

      result = described_class.blacklisted?(token)
      expect(result).to be true
    end
  end

  describe ".remove_refresh_token" do
    it "リフレッシュトークンを削除する" do
      payload = JsonWebToken.safe_decode(refresh_token)
      session_id = payload["session_id"]
      user_id = payload["user_id"]

      expect(JsonWebToken).to receive(:safe_decode).with(refresh_token).and_return(payload)
      expect(redis_instance).to receive(:del).with("refresh:session:#{user_id}:#{session_id}").and_return(1)

      result = described_class.remove_refresh_token(refresh_token)
      expect(result).to be true
    end

    it "無効なリフレッシュトークンの場合はfalseを返す" do
      expect(JsonWebToken).to receive(:safe_decode).with("invalid_token").and_return(nil)

      result = described_class.remove_refresh_token("invalid_token")
      expect(result).to be false
    end

    it "session_idがないリフレッシュトークンの場合はfalseを返す" do
      payload_without_session_id = {
        "user_id" => user.id,
        "exp" => 30.days.from_now.to_i
        # session_idがない
      }

      expect(JsonWebToken).to receive(:safe_decode).with(refresh_token).and_return(payload_without_session_id)

      result = described_class.remove_refresh_token(refresh_token)
      expect(result).to be false
    end

    it "Redisエラー時にはfalseを返す" do
      payload = {
        "user_id" => user.id,
        "session_id" => "test_session_id",
        "exp" => 30.days.from_now.to_i
      }

      expect(JsonWebToken).to receive(:safe_decode).with(refresh_token).and_return(payload)
      expect(redis_instance).to receive(:del).and_raise(Redis::CannotConnectError)
      expect(Rails.logger).to receive(:error).with(/Failed to remove refresh token/)

      result = described_class.remove_refresh_token(refresh_token)
      expect(result).to be false
    end
  end
end
