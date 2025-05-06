require "active_support/core_ext/integer/time"

# The test environment is used exclusively to run your application's
# test suite. You never need to work with it otherwise. Remember that
# your test database is "scratch space" for the test suite and is wiped
# and recreated between test runs. Don't rely on the data there!

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # テスト環境では、アプリケーションは通常の応答コードではなく例外を発生させます
  config.consider_all_requests_local = true
  config.action_controller.perform_caching = false
  config.cache_store = :null_store

  # Rails 8でのautoload実装の変更に対応
  config.autoload_lib(ignore: %w[assets tasks])

  # 電子メールサンドボックスを有効にすることでテスト中に実際のメールを送信しないようにします
  config.action_mailer.delivery_method = :test
  config.action_mailer.perform_deliveries = true
  config.action_mailer.perform_caching = false
  config.action_mailer.default_url_options = {host: "localhost", port: 3000}

  # 国際化の不足を検出して例外を発生させる
  config.i18n.raise_on_missing_translations = true

  # モデルのリレーションシップを積極的に読み込む (N+1クエリを回避)
  config.active_record.automatic_scope_inversing = true

  # RailsでSQLクエリロギングを無効にする
  config.active_record.verbose_query_logs = false

  # テストでのエラートレースを制限
  config.filter_parameters += [:password, :token]

  # 不要な処理を無効化してテスト高速化
  config.active_storage.service = :test
  config.active_job.queue_adapter = :test

  # テスト環境でのTransactional Fixturesを有効にする
  config.active_record.maintain_test_schema = true
  config.active_record.migration_error = :page_load

  # スレッドセーフなデータベーステスト (並列テスト対応)
  config.active_record.lock_optimistically = true
  config.active_support.test_order = :random

  # テスト中は不要な情報をログに出力しない
  config.log_level = :error

  # テスト実行時のパフォーマンス向上
  config.eager_load = false
  config.cache_classes = true

  # Test::Unit互換性サポート
  config.active_support.deprecation = :stderr

  # Raises error for missing translations.
  # config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  # config.action_view.annotate_rendered_view_with_filenames = true

  # 各テスト実行前にActive RecordのSQLタイマーをリセット
  config.after_initialize do
    ActiveSupport::Notifications.instrument("active_record.sql_timer_reset")
  end

  # FactoryBotを自動ロード
  begin
    require "factory_bot"
    FactoryBot.reload
  rescue LoadError => e
    puts "FactoryBotの読み込みに失敗しました: #{e.message}"
  end
end
