# frozen_string_literal: true

# テスト環境用のMockRedisクラス
class MockRedis
  def initialize
    @storage = {}
  end

  def setex(key, ttl, value)
    @storage[key] = {
      value: value,
      ttl: ttl,
      expires_at: Time.now.to_i + ttl
    }
    "OK"
  end

  def exists?(key)
    return false unless @storage.key?(key)

    # 有効期限切れの場合は自動的に削除
    if @storage[key][:expires_at] < Time.now.to_i
      @storage.delete(key)
      return false
    end

    true
  end

  def del(key)
    @storage.delete(key) ? 1 : 0
  end

  def ping
    "PONG"
  end

  def get(key)
    return nil unless exists?(key)
    @storage[key][:value]
  end

  def flushdb
    @storage = {}
    "OK"
  end

  def expire(key, ttl)
    return 0 unless @storage.key?(key)
    @storage[key][:ttl] = ttl
    @storage[key][:expires_at] = Time.now.to_i + ttl
    1
  end

  def ttl(key)
    return -2 unless @storage.key?(key)
    [@storage[key][:expires_at] - Time.now.to_i, 0].max
  end
end

# TokenBlacklistServiceモンキーパッチ
module TokenBlacklistServicePatch
  def self.prepended(base)
    class << base
      attr_accessor :redis_instance

      def redis
        @redis_instance ||= MockRedis.new
      end

      def redis=(instance)
        @redis_instance = instance
      end

      def configure(redis: nil)
        @redis_instance = redis || MockRedis.new
      end
    end
  end
end

# TokenBlacklistServiceパッチ適用モジュール
module MockRedisSetup
  def self.apply_patch
    return unless defined?(Rails) && Rails.env.test?

    if defined?(TokenBlacklistService)
      unless TokenBlacklistService.singleton_class.ancestors.include?(TokenBlacklistServicePatch)
        TokenBlacklistService.prepend(TokenBlacklistServicePatch)
        puts "✓ TokenBlacklistServiceにMockRedisパッチを適用しました"
      end
    else
      # Rails環境が読み込まれたらRails.applicationに後で適用するためのフックを設定
      puts "⚠️ TokenBlacklistServiceが見つからないため、遅延パッチを設定します"

      # TokenBlacklistServiceが読み込まれた時点でモンキーパッチを適用するためのコード
      at_exit do
        if defined?(TokenBlacklistService) && defined?(Rails) && Rails.env.test?
          apply_patch
        end
      end
    end
  end
end

# パッチ適用のタイミング制御
if defined?(Rails) && Rails.env.test?
  # Rails環境が既に利用可能な場合は直接パッチを適用
  MockRedisSetup.apply_patch
elsif ENV["RAILS_ENV"] == "test"
  # Rails環境が読み込まれたらパッチを適用するためのフックを設定
  puts "📌 MockRedisパッチの適用を遅延登録しました（Rails環境ロード後に適用）"
  at_exit do
    MockRedisSetup.apply_patch if defined?(Rails)
  end
end
