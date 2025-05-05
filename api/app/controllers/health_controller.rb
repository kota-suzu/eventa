class HealthController < ApplicationController
  # ヘルスチェックエンドポイント
  # 本番環境での監視やロードバランサーのチェック用
  def check
    response = base_response

    # 各サービスの状態をチェック
    check_database(response)
    check_redis(response)

    # ステータスコードを決定
    status_code = determine_status_code(response)
    render json: response, status: status_code
  end

  private

  def base_response
    {
      status: "ok",
      timestamp: Time.current.iso8601,
      environment: Rails.env,
      git_sha: ENV["GIT_SHA"] || "not_set",
      version: ENV["APP_VERSION"] || "development"
    }
  end

  def check_database(response)
    ActiveRecord::Base.connection_pool.with_connection do |conn|
      Timeout.timeout(0.5) do
        conn.select_value("SELECT 1")
        response[:database] = "connected"
      end
    end
  rescue Timeout::Error => e
    handle_db_timeout_error(response, e)
  rescue => e
    handle_db_error(response, e)
  end

  def handle_db_timeout_error(response, error)
    response[:database] = "timeout"
    response[:database_message] = "接続タイムアウト (0.5秒)"
    response[:status] = "error"
    log_warning("データベース接続タイムアウト", error)
  end

  def handle_db_error(response, error)
    response[:database] = "error"
    response[:database_message] = error.message
    response[:status] = "error"
    log_warning("データベース接続エラー", error, include_backtrace: true)
  end

  def check_redis(response)
    ensure_redis_loaded

    if redis_configured?
      Timeout.timeout(0.5) do
        redis = Redis.new(url: ENV["REDIS_URL"])
        redis.ping
        response[:redis] = "connected"
      end
    else
      response[:redis] = "not_configured"
    end
  rescue Timeout::Error => e
    handle_redis_timeout_error(response, e)
  rescue => e
    handle_redis_error(response, e)
  end

  def ensure_redis_loaded
    require "redis"
    require "timeout"
  rescue LoadError
    # Redis gem が見つからない場合は何もしない
  end

  def redis_configured?
    defined?(Redis) && ENV["REDIS_URL"].present?
  end

  def handle_redis_timeout_error(response, error)
    response[:redis] = "timeout"
    response[:redis_message] = "接続タイムアウト (0.5秒)"
    mark_as_warning(response)
    log_warning("Redis接続タイムアウト", error)
  end

  def handle_redis_error(response, error)
    response[:redis] = "error"
    response[:redis_message] = error.message
    mark_as_warning(response)
    log_warning("Redis接続警告", error, include_backtrace: true)
  end

  def mark_as_warning(response)
    # errorにはせず警告に留める
    response[:status] = "warning" if response[:status] == "ok"
  end

  def log_warning(message_prefix, error, include_backtrace: false)
    backtrace_info = include_backtrace ? "\n#{error.backtrace&.join("\n")}" : ""
    Rails.logger.warn "ヘルスチェック: #{message_prefix}: #{error.class}: #{error.message}#{backtrace_info}"
  end

  def determine_status_code(response)
    case response[:status]
    when "ok", "warning"
      :ok
    else
      :service_unavailable
    end
  end
end
