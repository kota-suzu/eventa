class HealthController < ApplicationController
  # ActionController::APIを継承しているため、verify_authenticity_tokenは利用できません
  # skip_before_action :verify_authenticity_token, if: -> { request.format.json? }

  # GET /health
  # Dockerのヘルスチェックで使用されるエンドポイント
  def index
    result = {
      status: "ok",
      timestamp: Time.current,
      environment: Rails.env,
      version: Rails.application.config.version || "development"
    }

    # データベース接続チェック
    begin
      db_status = ActiveRecord::Base.connection.execute("SELECT 1").to_a.present?
      result[:database] = db_status ? "connected" : "error"
    rescue => e
      result[:status] = "error"
      result[:database] = "error"
      result[:database_error] = e.message
    end

    # MySQLバージョンチェック
    begin
      if result[:database] == "connected"
        mysql_version = ActiveRecord::Base.connection.execute("SELECT VERSION() as version").to_a.first["version"]
        result[:mysql_version] = mysql_version
      end
    rescue => e
      result[:mysql_version_error] = e.message
    end

    # メモリ使用状況
    begin
      memory = `ps -o rss= -p #{Process.pid}`.to_i / 1024
      result[:memory_usage_mb] = memory
    rescue => e
      result[:memory_usage_error] = e.message
    end

    status_code = (result[:status] == "ok") ? 200 : 503
    render json: result, status: status_code
  end
end
