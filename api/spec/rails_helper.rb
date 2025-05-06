# frozen_string_literal: true

# This file is copied to spec/ when you run 'rails generate rspec:install'
require "spec_helper"
require "rspec/retry"  # rspec-retryを追加

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?

require "rspec/rails"

# データベースブートストラップを最初に読み込み
require_relative "support/test_database_bootstrap"
# Add additional requires below this line. Rails is not loaded until this point!
require "capybara/rails"
require "database_cleaner/active_record"

# データベース接続ヘルパーを読み込み
require_relative "../lib/db_connection_helper"

# テストデータベースの初期化を実行
begin
  # 新しい実装を使用してデータベーススキーマを検証
  TestDatabaseBootstrap.ensure_schema!

  # データベース接続が有効か確認
  unless ActiveRecord::Base.connection.active?
    # 接続問題がある場合はヘルパーを使用して再接続
    puts "テスト開始前のデータベース接続が無効です - 再接続を試みます"
    TestDBConnectionHelper.ensure_connection(max_attempts: 3, retry_wait: 2.0)
  end

  # 重要なテーブルが存在するか確認
  critical_tables = %w[users events]
  unless critical_tables.all? { |table| ActiveRecord::Base.connection.table_exists?(table) }
    missing_tables = critical_tables.reject { |table| ActiveRecord::Base.connection.table_exists?(table) }
    puts "テスト開始前のデータベース検証: 不足テーブル #{missing_tables.join(", ")}"

    # データベースの再構築を試みる
    if TestDatabaseBootstrap.respond_to?(:create_database_and_schema)
      TestDatabaseBootstrap.create_database_and_schema
    end
  end
rescue => e
  puts "テスト開始前のデータベース初期化エラー: #{e.class} - #{e.message}"
  puts e.backtrace.take(10).join("\n") if e.backtrace
  puts "Rails環境: #{Rails.env}"
  puts "データベース設定: #{ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).first.configuration_hash.inspect}"
  puts "手動でテストデータベースを修復するには: RAILS_ENV=test bundle exec rake db:test:repair"
end

# サポートファイル読み込みのための便利なパス指定
Dir[Rails.root.join("spec", "support", "**", "*.rb")].sort.each do |f|
  require f
rescue LoadError => e
  puts "サポートファイル読み込みエラー: #{f} - #{e.message}"
end

# Checks for pending migrations and applies them before tests are run.
# If you are not using ActiveRecord, you can remove these lines.
begin
  # Rails 8の場合は異なる方法でマイグレーション状態をチェック
  if defined?(ActiveRecord::Schema) && ActiveRecord::Schema.respond_to?(:check_pending!)
    ActiveRecord::Schema.check_pending!
  elsif ActiveRecord::Base.connection.migration_context.respond_to?(:needs_migration?)
    # Rails 7以前の場合
    ActiveRecord::Migration.maintain_test_schema!
  end
rescue => e
  puts "マイグレーションの検証中にエラーが発生しました: #{e.class} - #{e.message}"
  puts "これはRails 8での変更による問題である可能性があります。"
  puts "テストスイートは続行されますが、データベース関連のエラーに注意してください。"
end

# メトリクスコレクション設定
metrics_logger = Logger.new(File.join(Rails.root, "log", "test_metrics.log"))
metrics_logger.level = Logger::INFO

# テストパフォーマンス監視設定
enable_test_metrics = ENV["ENABLE_TEST_METRICS"] == "true"

RSpec.configure do |config|
  # Rails環境向け設定
  config.fixture_path = "#{::Rails.root}/spec/fixtures"
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  # リトライ設定（断続的な失敗対応）
  config.around(:each, :flaky) do |example|
    retry_limit = 3
    retry_count = 0
    begin
      example.run
    rescue RSpec::Expectations::ExpectationNotMetError => e
      retry_count += 1
      if retry_count <= retry_limit
        puts "Retrying flaky test (#{retry_count}/#{retry_limit}): #{example.metadata[:full_description]}"
        retry
      else
        raise
      end
    end
  end

  # メトリクス収集（オプション）
  if enable_test_metrics
    config.before(:suite) do
      @suite_start_time = Time.now
    end

    config.after(:suite) do
      duration = Time.now - @suite_start_time
      metrics_logger.info("Test suite duration: #{duration.round(2)}s")
    end

    config.around(:each) do |example|
      start_time = Time.now
      example.run
      duration = Time.now - start_time

      if duration > 1.0
        metrics_logger.info("Slow test (#{duration.round(2)}s): #{example.metadata[:full_description]}")
      end
    end
  end

  # テスト開始時の有用なデバッグ情報
  config.before(:suite) do
    puts "テスト環境: #{Rails.env}"
    puts "Railsバージョン: #{Rails.version}"
    puts "Ruby: #{RUBY_VERSION}-p#{RUBY_PATCHLEVEL} (#{RUBY_PLATFORM})"
    puts "テストデータベース: #{ActiveRecord::Base.connection.current_database}"
    puts "ActiveRecord設定: #{ActiveRecord::Base.connection_db_config.configuration_hash[:adapter]}"

    # 実際のデータベーステーブルを確認
    begin
      tables = ActiveRecord::Base.connection.tables
      puts "テーブル一覧: #{tables.join(", ")}"
    rescue => e
      puts "テーブル一覧取得エラー: #{e.message}"
    end
  end

  # テスト開始前にデータベースが正しく設定されていることを確認
  config.before(:suite) do
    # データベースの状態を確認
    TestDatabaseBootstrap.ensure_schema!
    puts "✓ テストデータベーススキーマの検証が完了しました"
  rescue => e
    puts "⚠️ テストデータベースのスキーマに問題があります: #{e.message}"
    puts "スキーマを修復します..."
    begin
      # スキーマ修復を試みる
      TestDatabaseBootstrap.create_database_and_schema
      puts "✓ データベーススキーマが修復されました"
    rescue => repair_error
      puts "テストデータベースの修復に失敗しました: #{repair_error.message}"
      puts repair_error.backtrace.take(10).join("\n") if repair_error.backtrace
      abort("テストデータベースの問題が解決できません。テスト実行を中止します。")
    end
  end

  # テストの並列実行対応（環境変数で指定されたプロセス番号に基づく）
  if ENV["TEST_ENV_NUMBER"]
    puts "テストプロセス番号: #{ENV["TEST_ENV_NUMBER"]}"
    config.around(:each) do |example|
      # 各テストで独自のトランザクションを使用し、プロセス間での競合を防ぐ
      ActiveRecord::Base.transaction(requires_new: true, joinable: false) do
        example.run
        raise ActiveRecord::Rollback # テスト終了時にロールバック
      end
    end
  end

  # テスト開始時に接続をリセットするオプション
  config.before(:each) do
    # 必要に応じて接続をリセット
    if ENV["RESET_CONNECTION_BEFORE_EACH"] == "true"
      ActiveRecord::Base.connection_pool.disconnect!
      ActiveRecord::Base.establish_connection
    end
  end

  # ファクトリーの自動ロード
  begin
    require "factory_bot_rails"
    require_relative "support/factory_bot"
    puts "✓ FactoryBot設定をロードしました"
  rescue LoadError => e
    puts "FactoryBotのロードに失敗しました: #{e.message}"
    puts "このエラーは無視されます"
  end

  # データベース接続の再試行設定
  if DatabaseConnectionHelper.respond_to?(:retriable_error?)
    config.around(:each) do |example|
      # テスト実行
      example.run
    rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished => e
      if TestDBConnectionHelper.respond_to?(:ensure_connection) && TestDBConnectionHelper.retriable_error?(e)
        puts "データベース接続エラーを検出 - 再接続を試みます: #{e.message}"
        ActiveRecord::Base.connection_pool.disconnect!
        ActiveRecord::Base.establish_connection
        retry
      else
        raise
      end
    end
  end
end

# Rails 8のParallelテスト互換性
if defined?(ActiveRecord::Base.connected_to)
  ActiveRecord::Base.connected_to(role: :writing) do
    puts "テストデータベース接続ロール: writing"
  end
end

# 最終データベース構成の確認
puts "テストデータベース準備完了: #{ActiveRecord::Base.connection.current_database} ✓"
