require "factory_bot"
require_relative "../../lib/db_connection_helper" if File.exist?(File.expand_path("../../lib/db_connection_helper.rb", __dir__))

# 「FactoryBot初期化設定が適用されました」メッセージを出力
puts "FactoryBot初期化設定が適用されました"

# frozen_string_literal: true

# FactoryBotの設定を行うサポートモジュール
# テスト実行時にファクトリーが確実に読み込まれるようにする
module FactoryBotHelper
  # ファクトリの初期化処理
  def self.initialize_factories
    # FactoryBotがすでに初期化されているか確認
    return if FactoryBot.factories.any?

    # データベース接続を確保
    ensure_database_connection

    Rails.logger.info("FactoryBotの初期化を開始します...") if defined?(Rails.logger)

    # 最大3回まで初期化を試行
    retries = 0
    max_retries = 3
    success = false

    begin
      # モデルのプリロード（必要に応じて）
      preload_models if defined?(Rails) && Rails.env.test?

      # FactoryBotの設定
      FactoryBot.definition_file_paths = [
        Rails.root.join("spec/factories"),
        Rails.root.join("test/factories")
      ].select { |path| Dir.exist?(path) }

      # ファクトリの読み込み
      FactoryBot.find_definitions

      # 登録されたファクトリの検証
      FactoryBot.factories.each do |factory|
        factory.compile
        Rails.logger.debug("ファクトリ '#{factory.name}' を検証済み") if defined?(Rails.logger)
      rescue => e
        Rails.logger.warn("ファクトリ '#{factory.name}' の検証に失敗: #{e.message}") if defined?(Rails.logger)
      end

      success = true
      print_factories_stats
    rescue => e
      retries += 1
      if retries < max_retries
        error_message = "FactoryBot初期化エラー (#{retries}/#{max_retries}): #{e.message}"
        Rails.logger.warn(error_message) if defined?(Rails.logger)
        puts error_message

        # 接続問題の可能性があるため、DBHを使用してリトライ
        if defined?(DatabaseConnectionHelper)
          DatabaseConnectionHelper.ensure_connection(max_attempts: 2)
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
        Rails.logger.error(error_message) if defined?(Rails.logger)
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
          Rails.logger.info("データベース接続OKです") if defined?(Rails.logger)
        rescue => e
          error_message = "データベース接続エラー: #{e.message}"
          Rails.logger.error(error_message) if defined?(Rails.logger)
          raise ActiveRecord::ConnectionNotEstablished, error_message
        end
      end
    end
  end

  # Railsモデルの事前読み込み（テスト環境での初期化に役立つ）
  def self.preload_models
    # Rails 6/7/8環境に対応した安全なモデルロード
    Rails.logger.debug("モデルのプリロードを開始...") if defined?(Rails.logger)

    begin
      # Rails 6/7ではeager_loadが機能
      if Rails.application.config.respond_to?(:eager_load_namespaces)
        Rails.application.eager_load!
        Rails.logger.debug("Rails標準のeager_loadでモデルをロードしました") if defined?(Rails.logger)
      # Rails 8ではautoload_libsが使用される可能性がある
      elsif Rails.application.config.respond_to?(:autoload_lib)
        # すでにautoload_libが設定されていると仮定
        Rails.logger.debug("Rails 8のautoload_libsでモデルをロードしました") if defined?(Rails.logger)
      else
        # 手動でモデルディレクトリを探索
        model_files = Dir[Rails.root.join("app/models/**/*.rb")]
        model_files.each do |file|
          require file
        rescue => e
          Rails.logger.warn("モデルファイル #{file} のロードに失敗: #{e.message}") if defined?(Rails.logger)
        end
        Rails.logger.debug("手動でモデルファイルをロードしました (#{model_files.size}ファイル)") if defined?(Rails.logger)
      end
    rescue => e
      Rails.logger.warn("モデルプリロード中にエラーが発生: #{e.message}") if defined?(Rails.logger)
    end
  end

  # ファクトリの統計情報を出力
  def self.print_factories_stats
    return unless FactoryBot.factories.any?

    factory_count = FactoryBot.factories.size
    trait_count = FactoryBot.factories.map { |f| f.definition.defined_traits.size }.sum

    message = "#{factory_count}件のファクトリと#{trait_count}件のトレイトを登録済み"
    Rails.logger.info(message) if defined?(Rails.logger)
    puts message

    # トップレベルのファクトリ一覧（デバッグ用）
    if defined?(Rails.logger) && Rails.logger.debug?
      factory_names = FactoryBot.factories.map(&:name).sort
      Rails.logger.debug("登録済みファクトリ: #{factory_names.join(", ")}")
    end
  end

  # テスト中にファクトリBotをリセット（主にデータベーススキーマ変更後）
  def self.reset
    FactoryBot.factories.clear
    FactoryBot.traits.clear
    FactoryBot.callbacks.clear
    FactoryBot.sequences.clear

    initialize_factories
  end
end

# RSpecに読み込まれた場合の設定
if defined?(RSpec)
  RSpec.configure do |config|
    # FactoryBotの短縮構文を有効化
    config.include FactoryBot::Syntax::Methods

    # テストスイート開始前にファクトリーを初期化
    config.before(:suite) do
      # データベースのクリーンアップ方法を設定
      DatabaseCleaner.strategy = :transaction
      DatabaseCleaner.clean_with(:truncation)

      # ファクトリーを初期化
      FactoryBotHelper.initialize_factories
    end

    # 各テスト前後の処理
    config.around(:each) do |example|
      # トランザクション内でテストを実行
      DatabaseCleaner.cleaning do
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
FactoryBotHelper.initialize_factories if !defined?(RSpec) && defined?(FactoryBot)

# Rails 8との互換性対応のため、テストデータベース接続時に自動的にファクトリーを初期化
if defined?(ActiveSupport::Notifications)
  ActiveSupport::Notifications.subscribe("active_record.connected") do
    FactoryBotHelper.initialize_factories if defined?(FactoryBot)
  end
end
