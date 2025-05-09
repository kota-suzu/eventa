# frozen_string_literal: true

# テスト用のRedisモッククラス
class MockRedis
  def initialize
    @storage = {}
  end

  def setex(key, ttl, value)
    @storage[key] = {value: value, ttl: ttl, created_at: Time.now.to_i}
    "OK"
  end

  def exists?(key)
    @storage.key?(key)
  end

  def del(key)
    @storage.delete(key) ? 1 : 0
  end

  def clear
    @storage = {}
  end

  def ping
    "PONG"
  end
end

# JsonWebTokenクラスのモック
class JsonWebToken
  def self.safe_decode(token)
    return nil if token == "invalid.token"

    if token == "valid.but.no.jti"
      # JTIのない有効なトークン
      return {
        "user_id" => 1,
        "exp" => (Time.now + 3600).to_i
      }
    end

    # JTIのある有効なトークン
    {
      "jti" => "test-jti-123",
      "user_id" => 1,
      "exp" => (Time.now + 3600).to_i
    }
  end
end

# TokenBlacklistServiceを読み込む前に、Redisをモック化
require_relative "../app/services/token_blacklist_service"

# モックRedisをセット
TokenBlacklistService.redis = MockRedis.new

# テスト実行
puts "===== JTIなしトークンテスト ====="

# 1. JTIのない有効なトークンをadd
result = TokenBlacklistService.add("valid.but.no.jti")
puts "JTIなしトークンの追加結果: #{result ? "成功" : "失敗"}"

# 2. JTIのない有効なトークンがブラックリストに含まれているか確認
blacklisted = TokenBlacklistService.blacklisted?("valid.but.no.jti")
puts "JTIなしトークンのブラックリスト確認: #{blacklisted ? "ブラックリスト済み" : "ブラックリストなし"}"

puts "===== テスト完了 ====="
