# frozen_string_literal: true

require "sidekiq"

Sidekiq.configure_server do |config|
  config.redis = {url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0")}

  # 本番環境のチューニング設定
  # 注: config/sidekiq.ymlでも設定可能。そちらが優先される。
  config.concurrency = ENV.fetch("SIDEKIQ_CONCURRENCY", 5).to_i
end

Sidekiq.configure_client do |config|
  config.redis = {url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0")}
end
