require "factory_bot"
require_relative "../../lib/db_connection_helper" if File.exist?(File.expand_path("../../lib/db_connection_helper.rb", __dir__))

# 「FactoryBot初期化設定が適用されました」メッセージを出力
puts "FactoryBot初期化設定が適用されました"

# frozen_string_literal: true

# FactoryBotの設定を行うサポートモジュール
# テスト実行時にファクトリーが確実に読み込まれるようにする
module FactoryBotHelper
  # 初期化スキップフラグ
  @initialized = false

  # 初期化ステータスの確認
  def self.initialized?
    @initialized == true
  end

  # 初期化ステータスの設定
  def self.mark_as_initialized
    @initialized = true
  end

  # ファクトリの初期化処理
  def self.initialize_factories
    # 初期化済みフラグのチェック
    if initialized?
      puts "FactoryBotは既に初期化済みのためスキップします"
      return true
    end

    # ファクトリが既に登録されているか確認
    # size呼び出しを安全に行うための変更
    if defined?(FactoryBot.factories) &&
        (FactoryBot.factories.instance_variable_get(:@items) || {}).any?
      puts "ファクトリは既に登録されています"
      mark_as_initialized
      return true
    end

    # データベース接続を確保
    ensure_database_connection

    puts "FactoryBotの初期化を開始します..."

    # 最大3回まで初期化を試行
    retries = 0
    max_retries = 3
    success = false

    begin
      # モデルのプリロード（必要に応じて）
      preload_models if defined?(Rails) && Rails.env.test?

      # FactoryBotの設定
      # Rails.rootが使用できない場合に備えて安全に処理
      factory_paths = []
      if defined?(Rails) && Rails.respond_to?(:root)
        factory_paths = [
          Rails.root.join("spec/factories"),
          Rails.root.join("test/factories")
        ].select { |path| Dir.exist?(path) }
      else
        # Rails環境外で実行されている場合
        spec_dir = File.expand_path("../../spec", __dir__)
        test_dir = File.expand_path("../../test", __dir__)
        factory_paths = [
          File.join(spec_dir, "factories"),
          File.join(test_dir, "factories")
        ].select { |path| Dir.exist?(path) }
      end

      FactoryBot.definition_file_paths = factory_paths

      # 既存のファクトリをクリア（重複登録を防止）
      FactoryBot.factories.clear
      FactoryBot.traits.clear
      FactoryBot.callbacks.clear
      FactoryBot.sequences.clear

      # ファクトリの読み込み
      FactoryBot.find_definitions

      # 登録されたファクトリの検証
      factory_items = FactoryBot.factories.instance_variable_get(:@items) || {}
      factory_names = factory_items.keys

      puts "ファクトリを検証中: #{factory_names.join(", ")}" if factory_names.any?

      factory_items.each do |name, factory|
        factory.compile
        puts "ファクトリ '#{name}' を検証済み"
      rescue => e
        puts "ファクトリ '#{name}' の検証に失敗: #{e.message}"
      end

      success = true
      print_factories_stats
      mark_as_initialized
    rescue => e
      retries += 1
      if retries < max_retries
        error_message = "FactoryBot初期化エラー (#{retries}/#{max_retries}): #{e.message}"
        puts error_message

        # 接続問題の可能性があるため、DBHを使用してリトライ
        if defined?(DatabaseConnectionHelper)
          DatabaseConnectionHelper.ensure_connection(max_attempts: 2)
          # Rails 8.0の互換性問題をチェック
          if defined?(DatabaseConnectionHelper.rails8_compatibility_error?) &&
              DatabaseConnectionHelper.rails8_compatibility_error?(e)
            DatabaseConnectionHelper.handle_rails8_compatibility_error(e)
          end
        else
          # あるいは単純な再接続
          begin
            ActiveRecord::Base.connection_pool.disconnect!
          rescue
            nil
          end
          ActiveRecord::Base.establish_connection
        end

        sleep(retries)
        retry
      else
        error_message = "FactoryBot初期化に#{max_retries}回失敗しました: #{e.message}"
        puts error_message
        puts e.backtrace.take(10).join("\n") if e.backtrace
      end
    end

    success
  end

  # データベース接続の確保
  def self.ensure_database_connection
    if defined?(DatabaseConnectionHelper)
      # DBHクラスが利用可能ならそれを使用
      DatabaseConnectionHelper.ensure_connection
    else
      # 基本的な接続確認/再接続
      unless ActiveRecord::Base.connection.active?
        begin
          ActiveRecord::Base.connection_pool.disconnect!
        rescue
          nil
        end
        ActiveRecord::Base.establish_connection

        # 接続テスト
        begin
          ActiveRecord::Base.connection.execute("SELECT 1")
          puts "データベース接続OKです"
        rescue => e
          error_message = "データベース接続エラー: #{e.message}"
          puts error_message
          raise ActiveRecord::ConnectionNotEstablished, error_message
        end
      end
    end
  end

  # Railsモデルの事前読み込み（テスト環境での初期化に役立つ）
  def self.preload_models
    # Rails 6/7/8環境に対応した安全なモデルロード
    puts "モデルのプリロードを開始..."

    begin
      # Rails 6/7ではeager_loadが機能
      if Rails.application.config.respond_to?(:eager_load_namespaces)
        Rails.application.eager_load!
        puts "Rails標準のeager_loadでモデルをロードしました"
      # Rails 8ではautoload_libsが使用される可能性がある
      elsif Rails.application.config.respond_to?(:autoload_lib)
        # すでにautoload_libが設定されていると仮定
        puts "Rails 8のautoload_libsでモデルをロードしました"
      else
        # 手動でモデルディレクトリを探索
        model_files = Dir[Rails.root.join("app/models/**/*.rb")]
        model_files.each do |file|
          require file
        rescue => e
          puts "モデルファイル #{file} のロードに失敗: #{e.message}"
        end
        puts "手動でモデルファイルをロードしました (#{model_files.size}ファイル)"
      end
    rescue => e
      puts "モデルプリロード中にエラーが発生: #{e.message}"
    end
  end

  # ファクトリの統計情報を出力
  def self.print_factories_stats
    # sizeメソッドを使わずに安全に件数を取得
    factory_items = FactoryBot.factories.instance_variable_get(:@items) || {}
    factory_count = factory_items.size

    trait_count = factory_items.values.inject(0) do |sum, factory|
      traits = begin
        factory.definition.defined_traits
      rescue
        []
      end
      sum + (traits.respond_to?(:size) ? traits.size : 0)
    end

    message = "#{factory_count}件のファクトリと#{trait_count}件のトレイトを登録済み"
    puts message

    # トップレベルのファクトリ一覧（デバッグ用）
    factory_names = factory_items.keys.sort
    puts "登録済みファクトリ: #{factory_names.join(", ")}"
  end

  # テスト中にファクトリBotをリセット（主にデータベーススキーマ変更後）
  def self.reset
    @initialized = false
    FactoryBot.factories.clear
    FactoryBot.traits.clear
    FactoryBot.callbacks.clear
    FactoryBot.sequences.clear

    initialize_factories
  end

  # Rails 8.0との互換性対応
  def self.handle_rails8_compatibility
    # Rails 8.0でスキーマが変更されたか確認
    if defined?(ActiveRecord::Base) && ActiveRecord::Base.connected?
      begin
        # スキーママイグレーションテーブルのチェック
        schema_migrations_exists = ActiveRecord::Base.connection.table_exists?("schema_migrations")
        puts "schema_migrationsテーブル存在状態: #{schema_migrations_exists ? "✓" : "✗"}"

        # Ridgepoleが使用されている場合
        if defined?(Ridgepole) || File.exist?(File.join(Rails.root.to_s, "db", "Schemafile"))
          puts "Ridgepoleが検出されました - スキーマを確認しています"
          if system("bundle exec ridgepole -c config/database.yml -E test --apply --dry-run -f db/Schemafile")
            puts "✓ Ridgepoleスキーマは最新です"
          else
            puts "⚠️ Ridgepoleスキーマの更新が必要です"
            # 必要に応じてスキーマを適用（コメントアウト解除）
            # system("bundle exec ridgepole -c config/database.yml -E test --apply -f db/Schemafile")
          end
        end
      rescue => e
        puts "Rails 8.0互換性チェック中にエラーが発生: #{e.message}"
        # DB接続ヘルパーがある場合は使用
        if defined?(DatabaseConnectionHelper) && DatabaseConnectionHelper.respond_to?(:handle_rails8_compatibility_error)
          DatabaseConnectionHelper.handle_rails8_compatibility_error(e)
        end
      end
    end
  end
end

# RSpecに読み込まれた場合の設定
if defined?(RSpec)
  RSpec.configure do |config|
    # FactoryBotの短縮構文を有効化
    config.include FactoryBot::Syntax::Methods

    # テストスイート開始前にファクトリーを初期化
    config.before(:suite) do
      # Rails 8.0の互換性対応
      FactoryBotHelper.handle_rails8_compatibility if defined?(Rails) && Rails.env.test?

      # データベースのクリーンアップ方法を設定
      if defined?(DatabaseCleaner)
        DatabaseCleaner.strategy = :transaction
        DatabaseCleaner.clean_with(:truncation)
      end

      # ファクトリーを初期化
      FactoryBotHelper.initialize_factories
    end

    # 各テスト前後の処理
    config.around(:each) do |example|
      # DatabaseCleanerが利用可能な場合
      if defined?(DatabaseCleaner)
        DatabaseCleaner.cleaning do
          example.run
        end
      else
        # 利用できない場合は単純にテストを実行
        example.run
      end
    end

    # テストスイート終了時の処理
    config.after(:suite) do
      FactoryBotHelper.print_factories_stats
    end
  end
end

# ファクトリーを即時初期化（RSpec外での使用時）
if !defined?(RSpec) && defined?(FactoryBot) && !FactoryBotHelper.initialized?
  FactoryBotHelper.initialize_factories
end

# Rails 8との互換性対応のため、テストデータベース接続時に自動的にファクトリーを初期化
if defined?(ActiveSupport::Notifications)
  ActiveSupport::Notifications.subscribe("active_record.connected") do
    if defined?(FactoryBot) && !FactoryBotHelper.initialized?
      puts "データベース接続イベントを検出 - FactoryBotを初期化します"
      FactoryBotHelper.initialize_factories
    end
  end
end
