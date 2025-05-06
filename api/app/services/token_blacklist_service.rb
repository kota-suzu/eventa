# frozen_string_literal: true

# JWTトークンのブラックリスト管理を行うサービスクラス
# Redisを使用してブラックリストされたトークンの管理を行います
class TokenBlacklistService
  class << self
    # Redis接続の取得
    def redis
      @redis ||= Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
    end

    # トークンをブラックリストに追加する
    # @param token [String] ブラックリストに追加するJWTトークン
    # @param reason [String] ブラックリストに追加する理由（オプション）
    # @return [Boolean] 追加が成功したかどうか
    def add(token, reason = "logout")
      # トークンをデコード
      payload = JsonWebToken.safe_decode(token)
      return false if payload.nil?

      # トークンのJTI（一意のID）とユーザーIDを取得
      jti = payload["jti"]
      user_id = payload["user_id"]
      exp = payload["exp"]

      return false if jti.nil? || user_id.nil? || exp.nil?

      # 現在時刻を取得
      current_time = Time.zone.now.to_i

      # 有効期限までの残り時間（秒）
      ttl = exp - current_time

      # 既に有効期限切れの場合は、ブラックリストに追加する必要がない
      return true if ttl <= 0

      # Redisにトークンの情報を保存
      # キー: "blacklist:token:{jti}"
      # 値: { user_id: xxx, reason: xxx, blacklisted_at: xxx }
      key = "blacklist:token:#{jti}"
      value = {
        user_id: user_id,
        reason: reason,
        blacklisted_at: current_time
      }.to_json

      # 有効期限までの時間（秒）をTTLとして設定
      redis.setex(key, ttl, value)

      true
    rescue Redis::BaseError => e
      Rails.logger.error "Failed to add token to blacklist: #{e.message}"
      false
    end

    # トークンがブラックリストに登録されているかを確認
    # @param token [String] チェックするJWTトークン
    # @return [Boolean] ブラックリストに含まれているかどうか
    def blacklisted?(token)
      payload = JsonWebToken.safe_decode(token)
      return true if payload.nil? # 無効なトークンはブラックリスト扱い

      jti = payload["jti"]
      return true if jti.nil? # JTIがないトークンはブラックリスト扱い

      # Redisでキーの存在を確認
      redis.exists?("blacklist:token:#{jti}")
    rescue Redis::BaseError => e
      Rails.logger.error "Failed to check token in blacklist: #{e.message}"
      true # エラー時は安全側に倒して「ブラックリストされている」と扱う
    end

    # リフレッシュトークンを削除する
    # @param token [String] 削除するリフレッシュトークン
    # @return [Boolean] 削除が成功したかどうか
    def remove_refresh_token(token)
      payload = JsonWebToken.safe_decode(token)
      return false if payload.nil?

      session_id = payload["session_id"]
      user_id = payload["user_id"]
      return false if session_id.nil? || user_id.nil?

      # リフレッシュトークンの情報をRedisから削除
      key = "refresh:session:#{user_id}:#{session_id}"
      redis.del(key)

      true
    rescue Redis::BaseError => e
      Rails.logger.error "Failed to remove refresh token: #{e.message}"
      false
    end

    # ユーザーのすべてのトークンを無効化
    # @param user_id [Integer] ユーザーID
    # @param reason [String] 無効化の理由
    # @return [Boolean] 成功したかどうか
    def invalidate_all_for_user(user_id, reason = "security_concern")
      # TODO: セッション管理テーブルを使用して、ユーザーに関連するすべてのトークンを無効化する実装
      # 現時点ではダミー実装
      true
    rescue Redis::BaseError => e
      Rails.logger.error "Failed to invalidate all tokens for user #{user_id}: #{e.message}"
      false
    end

    # ブラックリストのメンテナンス（期限切れエントリの削除など）
    def maintenance
      # Redisは自動的にTTLに基づいてキーを削除するため、
      # 特別なメンテナンス操作は必要ない
    end
  end
end
