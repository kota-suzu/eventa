# frozen_string_literal: true

# JWTトークンのブラックリスト管理を行うサービスクラス
# Redisを使用してブラックリストされたトークンの管理を行います
class TokenBlacklistService
  # Redisの基本設定
  DEFAULT_CONF = {url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0")}.freeze

  class << self
    # 外部から設定用API
    def configure(redis: Redis.new(**DEFAULT_CONF))
      @redis = redis
    end

    # Redis取得（private）
    private def redis
      # 設定済みのRedisがあればそれを使用
      return @redis if defined?(@redis) && @redis

      # 初期設定（デフォルトのRedis接続）
      configure
      @redis
    end

    # より短い参照用エイリアス（内部でのみ使用）
    private alias_method :r, :redis

    # トークンをブラックリストに追加する
    # @param token [String] ブラックリストに追加するJWTトークン
    # @param reason [String] ブラックリストに追加する理由
    # @return [Boolean] 追加が成功したかどうか
    def add(token, reason = "logout")
      payload = JsonWebToken.safe_decode(token)
      return false if payload.nil?

      # JTIがないトークンは常にブラックリスト扱い
      return true if missing_jti?(payload)

      user_id = payload["user_id"]
      exp = payload["exp"]
      return false if user_id.nil? || exp.nil?

      # 現在時刻を取得
      current_time = Time.zone.now.to_i

      # 有効期限までの残り時間（秒）
      ttl = exp - current_time

      # 既に有効期限切れの場合は、ブラックリストに追加する必要がない
      return true if expired?(payload)

      # Redisにトークンの情報を保存
      value = {
        user_id: user_id,
        reason: reason,
        blacklisted_at: current_time
      }.to_json

      # 有効期限までの時間（秒）をTTLとして設定
      r.setex(key(payload["jti"]), ttl, value) == "OK"
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

      # JTIがないトークンはブラックリスト扱い
      return true if missing_jti?(payload)

      # 有効期限切れトークンはブラックリスト扱い
      return true if expired?(payload)

      # Redisでキーの存在を確認
      r.exists?(key(payload["jti"]))
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
      r.del(refresh_key(user_id, session_id)) > 0
    rescue Redis::BaseError => e
      Rails.logger.error "Failed to remove refresh token: #{e.message}"
      false
    end

    # ユーザーのすべてのトークンを無効化
    # @param user_id [Integer] ユーザーID
    # @param reason [String] 無効化の理由
    # @return [Boolean] 成功したかどうか
    def invalidate_all_for_user(user_id, reason = "security_concern")
      # TODO(!security): セッション管理テーブルを使用して、ユーザーに関連するすべてのトークンを無効化する実装
      # パスワード変更時やセキュリティ上の理由でアカウントに関連する全トークンを無効化する機能
      # Redisインデックスを使用してユーザーIDに関連するすべてのJTIを検索する方法を実装
      true
    rescue Redis::BaseError => e
      Rails.logger.error "Failed to invalidate all tokens for user #{user_id}: #{e.message}"
      false
    end

    # ブラックリストのメンテナンス（期限切れエントリの削除など）
    def maintenance
      # Redisは自動的にTTLに基づいてキーを削除するため、
      # 特別なメンテナンス操作は必要ない

      # TODO(!performance): Redisのメモリ使用量監視とクリーンアップ機能の追加
      # 長期的な運用では、大量のトークンがブラックリストに追加される可能性があるため、
      # Redisのメモリ使用状況を監視し、必要に応じてクリーンアップする機能を追加する
    end

    private

    # ブラックリストのキーを生成
    def key(jti)
      "blacklist:token:#{jti}"
    end

    # リフレッシュトークンのキーを生成
    def refresh_key(user_id, session_id)
      "refresh:session:#{user_id}:#{session_id}"
    end

    # JTIが欠落しているかをチェック
    def missing_jti?(payload)
      payload["jti"].nil?
    end

    # トークンが有効期限切れかをチェック
    def expired?(payload)
      payload["exp"].to_i <= Time.zone.now.to_i
    end
  end
end
