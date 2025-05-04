# frozen_string_literal: true

# IPアドレス操作のためのライブラリ
require "ipaddr"

# レート制限による攻撃対策
class Rack::Attack
  # プライベートネットワークとCloudFrontからのリクエストを信頼する
  # 本番環境ではロードバランサー/CDN経由でアクセスされるため
  # リクエスト元の実際のIPアドレスを取得するために必要
  safelist("trusted networks") do |req|
    # RFC 1918 プライベートIPv4アドレス範囲
    req.ip == "127.0.0.1" || # ローカル開発
      IPAddr.new("10.0.0.0/8").include?(req.ip) || # AWS内部
      IPAddr.new("172.16.0.0/12").include?(req.ip) || # Docker
      IPAddr.new("192.168.0.0/16").include?(req.ip) # プライベートネットワーク
  end

  # セルフスロットリング - IPアドレスごとのレート制限

  # ログイン試行回数を制限
  throttle("logins/ip", limit: 5, period: 20.seconds) do |req|
    req.ip if req.path == "/api/v1/auth/login" && req.post? # 正しいパスに修正
  end

  # 予約APIへのレート制限
  throttle("reservations/ip", limit: 10, period: 1.minute) do |req|
    req.ip if req.path == "/api/v1/ticket_reservations" && req.post?
  end

  # 全般的なAPIリクエスト制限
  throttle("api/ip", limit: 300, period: 5.minutes) do |req|
    req.ip if req.path.start_with?("/api/v1/")
  end

  # レスポンスの設定
  self.throttled_response = ->(env) {
    retry_after = (env["rack.attack.match_data"] || {})[:period]
    [
      429,
      {"Content-Type" => "application/json", "Retry-After" => retry_after.to_s},
      [{error: "リクエスト数が多すぎます。しばらく待ってから再試行してください。"}.to_json]
    ]
  }
end
