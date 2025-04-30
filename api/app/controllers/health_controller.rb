class HealthController < ApplicationController
  # ヘルスチェックエンドポイント
  # 本番環境での監視やロードバランサーのチェック用
  def check
    response = {
      status: "ok",
      timestamp: Time.current.iso8601,
      environment: Rails.env,
      git_sha: ENV["GIT_SHA"] || "not_set",
      version: ENV["APP_VERSION"] || "development"
    }
    
    # データベース接続チェック（コネクションプール利用＋タイムアウト設定）
    begin
      ActiveRecord::Base.connection_pool.with_connection do |conn|
        Timeout.timeout(0.5) do
          conn.select_value("SELECT 1")
          response[:database] = "connected"
        end
      end
    rescue Timeout::Error => e
      response[:database] = "timeout"
      response[:database_message] = "接続タイムアウト (0.5秒)"
      response[:status] = "error"
      Rails.logger.warn "ヘルスチェック: データベース接続タイムアウト: #{e.class}: #{e.message}"
    rescue StandardError => e
      response[:database] = "error"
      response[:database_message] = e.message
      response[:status] = "error"
      Rails.logger.warn "ヘルスチェック: データベース接続エラー: #{e.class}: #{e.message}\n#{e.backtrace&.join("\n")}"
    end
    
    # Redis接続チェック - Redis gemが存在するか安全に確認（タイムアウト設定）
    begin
      # まずRedisクラスが存在するか安全に確認
      require 'redis' rescue nil
      require 'timeout' rescue nil
      
      if defined?(Redis) && ENV["REDIS_URL"].present?
        Timeout.timeout(0.5) do
          redis = Redis.new(url: ENV["REDIS_URL"])
          redis.ping
          response[:redis] = "connected"
        end
      else
        response[:redis] = "not_configured"
      end
    rescue Timeout::Error => e
      response[:redis] = "timeout"
      response[:redis_message] = "接続タイムアウト (0.5秒)"
      response[:status] = "warning" if response[:status] == "ok" # errorにはせず警告に留める
      Rails.logger.warn "ヘルスチェック: Redis接続タイムアウト: #{e.class}: #{e.message}"
    rescue StandardError => e
      response[:redis] = "error"
      response[:redis_message] = e.message
      response[:status] = "warning" if response[:status] == "ok" # errorにはせず警告に留める
      Rails.logger.warn "ヘルスチェック: Redis接続警告: #{e.class}: #{e.message}\n#{e.backtrace&.join("\n")}"
    end
    
    status_code = response[:status] == "ok" ? :ok : (response[:status] == "warning" ? :ok : :service_unavailable)
    render json: response, status: status_code
  end
end