# frozen_string_literal: true

require "sidekiq-scheduler"

Sidekiq.configure_server do |config|
  config.on(:startup) do
    # テスト環境ではスケジューラを完全に無効化
    if Rails.env.test?
      Sidekiq.logger.info "テスト環境のためスケジューラを無効化します"
      Sidekiq::Scheduler.enabled = false
      return
    end

    Sidekiq::Scheduler.enabled = true
    Sidekiq::Scheduler.dynamic = true

    # 設定ファイルのパスを指定
    schedule_file = File.expand_path("../../sidekiq.yml", __FILE__)
    if File.exist?(schedule_file)
      Sidekiq.logger.info "スケジューラ設定を読み込み中: #{schedule_file}"
      yaml_content = YAML.load_file(schedule_file)

      # YAMLからスケジュール部分だけを抽出
      if yaml_content.is_a?(Hash) && yaml_content[:scheduler] && yaml_content[:scheduler][:schedule]
        Sidekiq.schedule = yaml_content[:scheduler][:schedule]
        Sidekiq::Scheduler.reload_schedule!
      else
        Sidekiq.logger.warn "スケジューラ設定が正しい形式ではありません"
      end
    else
      Sidekiq.logger.warn "スケジューラ設定ファイルが見つかりません: #{schedule_file}"
    end
  end
end
