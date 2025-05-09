# frozen_string_literal: true

require "rails_helper"
require "support/mock_redis"

# TokenBlacklistServiceのテストクラス
RSpec.describe TokenBlacklistService do
  let(:user_id) { 1 }
  let(:jti) { SecureRandom.uuid }
  let(:exp) { Time.zone.now.to_i + 3600 } # 1時間後

  # 各テストごとに新しいモックRedisを設定
  around do |example|
    # モックRedisを設定してテスト実行
    mock_redis = MockRedis.new
    described_class.configure(redis: mock_redis)

    # ブロックでTimecop.freezeを使って時間を固定してテスト実行
    Timecop.freeze do
      example.run
    end
  ensure
    # テスト後にモックをリセット
    described_class.configure(redis: MockRedis.new)
  end

  # テスト用有効トークン生成
  def create_token_with_jti
    JsonWebToken.encode({
      user_id: user_id,
      jti: jti
    }, exp: exp)
  end

  # テスト用JTIなしトークン生成
  def create_token_without_jti
    JsonWebToken.encode({
      user_id: user_id
    }, exp: exp)
  end

  describe ".add" do
    context "有効なトークンの場合" do
      let(:token) { create_token_with_jti }

      it "ブラックリストに追加して true を返す" do
        expect(described_class.add(token, "test")).to be true
      end

      it "追加したトークンがブラックリストに含まれる" do
        described_class.add(token, "test")
        expect(described_class.blacklisted?(token)).to be true
      end
    end

    context "JTIのないトークンの場合" do
      let(:token) { create_token_without_jti }

      it "true を返す" do
        expect(described_class.add(token)).to be true
      end
    end

    context "無効なトークンの場合" do
      it "false を返す" do
        expect(described_class.add("invalid.token")).to be false
      end
    end

    context "Redisエラー発生時" do
      before do
        allow(TokenBlacklistService).to receive(:redis).and_raise(Redis::CannotConnectError)
      end

      it "falseを返す" do
        expect(described_class.add(create_token_with_jti)).to be false
      end
    end
  end

  describe ".blacklisted?" do
    context "ブラックリスト済みのトークンの場合" do
      let(:token) { create_token_with_jti }

      before do
        described_class.add(token, "test")
      end

      it "true を返す" do
        expect(described_class.blacklisted?(token)).to be true
      end
    end

    context "ブラックリストにないトークンの場合" do
      let(:token) { create_token_with_jti }

      it "false を返す" do
        expect(described_class.blacklisted?(token)).to be false
      end
    end

    context "JTIがないトークンの場合" do
      let(:token) { create_token_without_jti }

      it "true を返す（JTIがないトークンは常にブラックリスト扱い）" do
        expect(described_class.blacklisted?(token)).to be true
      end
    end

    context "無効なトークンの場合" do
      it "true を返す（無効なトークンは常にブラックリスト扱い）" do
        expect(described_class.blacklisted?("invalid.token")).to be true
      end
    end

    context "有効期限切れのトークンの場合" do
      let(:token) do
        JsonWebToken.encode(
          {user_id: user_id, jti: jti},
          exp: Time.zone.now.to_i - 10 # 現在時刻より10秒前
        )
      end

      it "true を返す（有効期限切れのトークンは常にブラックリスト扱い）" do
        expect(described_class.blacklisted?(token)).to be true
      end
    end

    context "Redisエラー発生時" do
      before do
        allow(TokenBlacklistService).to receive(:redis).and_raise(Redis::CannotConnectError)
      end

      it "trueを返す（セキュリティ上、Redisエラー時は安全側にする）" do
        expect(described_class.blacklisted?(create_token_with_jti)).to be true
      end
    end
  end

  describe ".remove_refresh_token" do
    let(:session_id) { SecureRandom.uuid }
    let(:token) do
      JsonWebToken.encode(
        {user_id: user_id, session_id: session_id},
        exp: exp
      )
    end

    context "有効なトークンの場合" do
      before do
        mock_redis = MockRedis.new
        described_class.configure(redis: mock_redis)
        # リフレッシュトークンをセット
        key = "refresh:session:#{user_id}:#{session_id}"
        mock_redis.setex(key, 3600, "some_data")
      end

      it "トークンが削除される" do
        expect(described_class.remove_refresh_token(token)).to be true
      end
    end

    context "無効なトークンの場合" do
      it "falseを返す" do
        expect(described_class.remove_refresh_token("invalid.token")).to be false
      end
    end

    context "session_idがないトークンの場合" do
      let(:invalid_token) do
        JsonWebToken.encode({user_id: user_id}, exp: exp)
      end

      it "falseを返す" do
        expect(described_class.remove_refresh_token(invalid_token)).to be false
      end
    end

    context "Redisエラー発生時" do
      before do
        allow(TokenBlacklistService).to receive(:redis).and_raise(Redis::CannotConnectError)
      end

      it "falseを返す" do
        expect(described_class.remove_refresh_token(token)).to be false
      end
    end
  end
end
