# frozen_string_literal: true

require "database_cleaner/active_record"
require_relative "../../lib/db_connection_helper" if File.exist?(File.expand_path("../../lib/db_connection_helper.rb", __dir__))

RSpec.configure do |config|
  # テスト実行前に一度だけデータベースをクリーンアップ
  config.before(:suite) do
    # テスト開始前にテーブルの存在を確認
    begin
      connection = ActiveRecord::Base.connection
      tables = connection.tables
      expect(tables).to include("users"), "usersテーブルが存在しません。テスト環境のスキーマを確認してください。"
    rescue => e
      puts "テーブル確認中にエラーが発生しました: #{e.message}"
      puts "テスト環境のデータベースを修復します..."
      begin
        Rake::Task["db:test:repair"].invoke if defined?(Rake::Task) && Rake::Task.task_defined?("db:test:repair")
      rescue => repair_error
        puts "データベース修復中にエラーが発生: #{repair_error.message}"
      end
    end

    # トランザクション分離レベルをREAD-COMMITTEDに設定（競合回避）
    isolation_variable = nil

    if defined?(DatabaseConnectionHelper) && DatabaseConnectionHelper.respond_to?(:isolation_variable_name)
      # 利用可能な場合はクラスのメソッドを使用
      isolation_variable = DatabaseConnectionHelper.isolation_variable_name
      DatabaseConnectionHelper.set_isolation_level("READ-COMMITTED")
    elsif ActiveRecord::Base.connection.adapter_name.downcase.include?("mysql")
      # 直接MySQLのバージョンを確認して分離レベル変数を設定
      begin
        mysql_version = ActiveRecord::Base.connection.select_value("SELECT @@version")
        isolation_variable = if mysql_version.to_s.start_with?("8.")
          "transaction_isolation"
        else
          "tx_isolation"
        end
        ActiveRecord::Base.connection.execute("SET #{isolation_variable} = 'READ-COMMITTED'")
      rescue => e
        puts "トランザクション分離レベル設定エラー: #{e.message}"
        # 一般的なコマンドでの設定を試みる
        begin
          ActiveRecord::Base.connection.execute("SET TRANSACTION ISOLATION LEVEL READ COMMITTED")
        rescue => e2
          puts "代替トランザクション分離レベル設定エラー: #{e2.message}"
        end
      end
    end

    puts "\nデータベースクリーナー設定完了 (#{ENV["TEST_ENV_NUMBER"] || "メイン"})"

    # 現在の分離レベルを確認（isolationVariableが設定されている場合のみ）
    if isolation_variable
      begin
        current_isolation = ActiveRecord::Base.connection.select_value("SELECT @@#{isolation_variable}")
        puts "現在のトランザクション分離レベル: #{current_isolation}"
      rescue => e
        puts "分離レベル取得エラー: #{e.message}"
      end
    end

    # DatabaseCleanerの戦略を設定
    DatabaseCleaner.clean_with(:truncation)
    DatabaseCleaner.strategy = :transaction
  end

  # 各テストの前にデータベースクリーナーを開始
  config.before(:each) do
    DatabaseCleaner.start
  end

  # 各テストの後にデータベースをクリーンアップ
  config.after(:each) do
    DatabaseCleaner.clean
  end

  # 並列テストのためのヘルパーメソッド（並列テスト実行時に使用）
  config.around(:each, :js) do |example|
    # JSテスト（Capybaraなど）で使用するための設定
    # トランザクションの代わりに切り替えが必要
    DatabaseCleaner.strategy = :truncation
    example.run
    DatabaseCleaner.strategy = :transaction
  end

  # DatabaseCleanerの後処理
  config.after(:suite) do
    puts "テスト完了後のデータベース状態を確認中..."
    begin
      connection = ActiveRecord::Base.connection
      if connection.active?
        tables = connection.tables
        migration_table = tables.include?("schema_migrations")
        users_table = tables.include?("users")
        puts "必須テーブル存在確認: schema_migrations(#{migration_table}), users(#{users_table})"
      else
        puts "データベース接続がアクティブではありません"
      end
    rescue => e
      puts "テスト後のデータベース状態確認中にエラー: #{e.message}"
    end
  end

  # デフォルトはトランザクション戦略（高速だが、並列テストで競合する可能性あり）
  config.before(:each) do
    # デフォルト戦略はトランザクション（高速）
    DatabaseCleaner.strategy = :transaction
  end

  # システムスペック、リクエストスペック、または他のデータベース接続を含むテストではトランケーション戦略を使用
  # これはより遅いが、複数接続間で整合性を保つ
  config.before(:each, type: :feature) do
    DatabaseCleaner.strategy = :truncation
  end

  config.before(:each, type: :request) do
    DatabaseCleaner.strategy = :truncation
  end

  # 明示的にtagをつけたテストではトランケーション戦略を使用
  config.before(:each, db_clean: :truncation) do
    DatabaseCleaner.strategy = :truncation
  end

  # テスト用の別々のトランザクションを処理するヘルパーメソッド
  # デッドロックのリスクを軽減するために使用
  config.around(:each, :isolate_database) do |example|
    ActiveRecord::Base.transaction do
      example.run
      raise ActiveRecord::Rollback
    end
  end

  # JS/Systemテスト用の設定
  config.before(:each, type: :system) do
    # Systemテストでは切断されたセッション間でデータを共有するため、truncationが必要
    DatabaseCleaner.strategy = :truncation
  end

  # データベース接続リセット（接続エラー対応）
  config.before(:each, :db_reset) do
    ActiveRecord::Base.connection_pool.disconnect!
    ActiveRecord::Base.connection_pool.clear_reloadable_connections!
    ActiveRecord::Base.establish_connection
  end

  # parallelテストの場合のスレッドセーフな設定
  config.before(:each, :parallel) do
    # parallelテストではトランザクションが干渉する可能性があるため、truncationを使用
    DatabaseCleaner.strategy = :truncation
  end

  # 一時的にデータベース接続が失敗した場合に再試行
  config.around(:each, :db) do |example|
    example.run
  rescue ActiveRecord::StatementInvalid => e
    if /server has gone away|Lost connection|MySQL server has gone away/i.match?(e.message)
      puts "データベース接続が切断されました。再接続を試みます..."
      # 再接続処理
      if defined?(TestDBConnectionHelper)
        TestDBConnectionHelper.ensure_connection
      else
        ActiveRecord::Base.connection_pool.disconnect!
        ActiveRecord::Base.establish_connection
      end
      retry
    else
      raise
    end
  end
end

# データベースクリーニング関連の拡張ヘルパー機能
module DatabaseCleanerHelper
  # 特定のテーブルをクリーンアップ
  def self.clean_table(table_name)
    ActiveRecord::Base.connection.execute("DELETE FROM #{table_name}")
  rescue => e
    Rails.logger.error("テーブル #{table_name} のクリーンアップに失敗: #{e.message}") if defined?(Rails.logger)
  end

  # データベース接続を再確立
  def self.reconnect!
    if defined?(TestDBConnectionHelper)
      TestDBConnectionHelper.ensure_connection
    else
      ActiveRecord::Base.connection_pool.disconnect!
      ActiveRecord::Base.establish_connection
      Rails.logger.info("データベース接続を再確立しました") if defined?(Rails.logger)
    end
  end

  # テストデータベースの健全性を検証
  def self.verify_test_database
    # 重要なテーブルが存在することを確認

    connection = ActiveRecord::Base.connection
    tables = connection.tables
    critical_tables = %w[users events]

    missing_tables = critical_tables - tables
    if missing_tables.any?
      message = "テストデータベースに重要なテーブルが不足しています: #{missing_tables.join(", ")}"
      Rails.logger.error(message) if defined?(Rails.logger)

      # Rakeタスクで修復を試みる
      if defined?(Rake::Task) && Rake::Task.task_defined?("db:test:repair")
        Rails.logger.info("データベース修復タスクを実行します...") if defined?(Rails.logger)
        Rake::Task["db:test:repair"].invoke
        return verify_test_database # 再帰的に確認
      end

      return false
    end

    # トランザクション機能を確認
    transaction_check = -> {
      ActiveRecord::Base.transaction do
        ActiveRecord::Base.connection.execute("SELECT 1")
        raise ActiveRecord::Rollback
      end
      true
    }

    transaction_ok = begin
      transaction_check.call
    rescue => e
      Rails.logger.error("トランザクションテストに失敗: #{e.message}") if defined?(Rails.logger)
      false
    end

    unless transaction_ok
      Rails.logger.error("トランザクション機能が正常に動作していません") if defined?(Rails.logger)
      return false
    end

    true # すべてのチェックに合格
  rescue => e
    Rails.logger.error("テストデータベース検証中にエラー: #{e.message}") if defined?(Rails.logger)
    false
  end

  # データベース接続とトランザクション分離レベルを最適化
  def self.optimize_database_connection
    return unless ActiveRecord::Base.connection.active?

    begin
      # MySQLバージョン検出とトランザクション分離レベル設定
      if defined?(DatabaseConnectionHelper) && DatabaseConnectionHelper.respond_to?(:mysql_version)
        # 利用可能ならDBConnectionHandlerクラスの機能を使用
        DatabaseConnectionHelper.mysql_version
        DatabaseConnectionHelper.isolation_variable_name
        DatabaseConnectionHelper.set_isolation_level("READ-COMMITTED")
      else
        # 直接クエリでの対応
        mysql_version = begin
          ActiveRecord::Base.connection.select_value("SELECT @@version")
        rescue => e
          puts "MySQLバージョン取得エラー: #{e.message}" if defined?(Rails.logger)
          nil
        end

        if mysql_version
          # バージョンによって分離レベル変数が異なる
          variable_name = mysql_version.to_s.start_with?("8.") ? "transaction_isolation" : "tx_isolation"
          begin
            ActiveRecord::Base.connection.execute("SET #{variable_name} = 'READ-COMMITTED'")
          rescue => e
            puts "トランザクション分離レベル設定エラー: #{e.message}" if defined?(Rails.logger)
            # 一般的な構文での設定を試みる
            begin
              ActiveRecord::Base.connection.execute("SET TRANSACTION ISOLATION LEVEL READ COMMITTED")
            rescue => e2
              puts "代替トランザクション分離レベル設定エラー: #{e2.message}" if defined?(Rails.logger)
            end
          end
        end
      end

      # 適切なデータベースフラグを設定
      begin
        ActiveRecord::Base.connection.execute("SET @@SESSION.autocommit = 1")
      rescue
        nil
      end

      # 接続タイムアウトと待機時間を設定
      database_config = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).first.configuration_hash

      # ActiveRecordのコネクションプール設定
      if database_config[:pool].to_i < 5
        Rails.logger.info("コネクションプールサイズを5に最適化します") if defined?(Rails.logger)
        ActiveRecord::Base.connection_pool.disconnect!
        temp_config = database_config.dup
        temp_config[:pool] = 5
        ActiveRecord::Base.establish_connection(temp_config)
      end

      true
    rescue => e
      Rails.logger.error("データベース接続最適化エラー: #{e.message}") if defined?(Rails.logger)
      false
    end
  end
end

# 初期確認
begin
  DatabaseCleanerHelper.verify_test_database
rescue => e
  puts "テストデータベースの事前確認に失敗しました: #{e.message}"
  # 例外は発生させず、テスト実行時の検証に任せる
end
