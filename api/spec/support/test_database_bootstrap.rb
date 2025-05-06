# frozen_string_literal: true

# テストデータベース初期化用のユーティリティモジュール
# rails_helper.rbから切り出して、コード品質を向上・メンテナンス性向上
module TestDatabaseBootstrap
  # データベーススキーマの検証と初期化を実行
  # @return [Boolean] 成功した場合はtrue、それ以外はfalse
  def self.ensure_schema!
    # データベース接続の検証
    begin
      ActiveRecord::Base.connection.verify!
      ActiveRecord::Base.connection.reconnect! unless ActiveRecord::Base.connection.active?
    rescue => e
      puts "データベース接続エラー: #{e.class} - #{e.message}"
      create_database_and_schema
      return true
    end

    begin
      # テーブルの存在確認 - スキーマがロードされているかチェック
      if ActiveRecord::Base.connection.table_exists?("schema_migrations")
        # Rails 8互換の方法でマイグレーションのチェック
        begin
          if defined?(ActiveRecord::Schema) && ActiveRecord::Schema.respond_to?(:check_pending!)
            ActiveRecord::Schema.check_pending!
          elsif ActiveRecord::Base.connection.migration_context.respond_to?(:needs_migration?)
            # Rails 7まで
            if ActiveRecord::Base.connection.migration_context.needs_migration?
              puts "保留中のマイグレーションがあります。スキーマを再ロードします。"
              load_schema
            end
          elsif defined?(ActiveRecord::Migrator) && ActiveRecord::Migrator.respond_to?(:needs_migration?)
            # Rails 8以降の一部バージョン
            if ActiveRecord::Migrator.needs_migration?
              puts "保留中のマイグレーションがあります。スキーマを再ロードします。"
              load_schema
            end
          end
        rescue ActiveRecord::PendingMigrationError => e
          puts "マイグレーションエラー: #{e.message}"
          load_schema
        end
      else
        # schema_migrationsテーブルが存在しない場合はスキーマをロード
        puts "schema_migrationsテーブルが存在しません。テストデータベースを初期化します。"
        create_database_and_schema
      end

      # 重要なテーブルが存在するか確認
      critical_tables = %w[events users tickets ticket_types participants reservations]
      existing_tables = ActiveRecord::Base.connection.tables
      missing_tables = critical_tables - existing_tables

      if missing_tables.any?
        puts "重要なテーブルが不足しています: #{missing_tables.join(", ")}"
        puts "スキーマを強制的に再ロードします。"
        load_schema
      end

      puts "✓ テストデータベーススキーマの検証が完了しました"
      true
    rescue => e
      repair_database(e)
    end
  end

  # データベース修復を試みる
  # @param error [Exception] 発生したエラー
  # @return [Boolean] 修復に成功した場合はtrue、それ以外はfalse
  def self.repair_database(error)
    puts "データベース接続/スキーマ検証エラー: #{error.class} - #{error.message}"

    begin
      # Railsのネイティブコマンドを使用した修復を試みる
      create_database_and_schema

      # 修復の確認
      if ActiveRecord::Base.connection.table_exists?("schema_migrations")
        critical_tables = %w[events users tickets ticket_types participants reservations]
        existing_tables = ActiveRecord::Base.connection.tables
        missing_tables = critical_tables - existing_tables

        if missing_tables.any?
          puts "修復後も重要なテーブルが不足しています: #{missing_tables.join(", ")}"
          false
        else
          puts "✓ データベース修復に成功しました"
          true
        end
      else
        puts "データベース修復に失敗しました: schema_migrationsテーブルが存在しません"
        false
      end
    rescue => repair_error
      puts "データベース修復に失敗しました: #{repair_error.message}"
      puts "手動での対応が必要です: make repair-test-db を実行してください"
      false
    end
  end

  # データベースとスキーマを作成する
  def self.create_database_and_schema
    puts "テストデータベースを再作成します..."
    begin
      # データベースをドロップして再作成
      ActiveRecord::Tasks::DatabaseTasks.drop_current
      ActiveRecord::Tasks::DatabaseTasks.create_current

      # スキーマをロード
      load_schema
    rescue => e
      puts "データベース再作成中にエラーが発生しました: #{e.message}"
      # 接続をリセットして再試行
      ActiveRecord::Base.connection_pool.disconnect!
      ActiveRecord::Base.establish_connection
      load_schema
    end
  end

  # スキーマをロードする
  def self.load_schema
    puts "スキーマをロードします..."
    begin
      # 標準のスキーマロード方法
      ActiveRecord::Schema.load_schema
    rescue => e
      puts "標準スキーマロードに失敗しました: #{e.message}"
      puts "Ridgepoleでのスキーマ適用を試みます..."
      begin
        # Ridgepoleでのスキーマ適用を試みる (Railsプロセス内で直接実行)
        ENV["RAILS_ENV"] = "test"
        system("bundle exec ridgepole -c config/database.yml -E test --apply -f db/Schemafile")
      rescue => ridgepole_error
        puts "Ridgepoleでのスキーマ適用に失敗しました: #{ridgepole_error.message}"
      end
    end

    # FactoryBotのリロード
    if defined?(FactoryBot)
      puts "FactoryBot設定をリロードします..."
      FactoryBot.reload
    end
  end
end

# RSpecに読み込まれたときに自動的に実行
if defined?(RSpec)
  begin
    TestDatabaseBootstrap.ensure_schema!
  rescue => e
    puts "TestDatabaseBootstrap実行中のエラー: #{e.message}"
    puts "テストデータベースの初期化に失敗しました。make repair-test-db を実行して修復してください。"
    exit(1)
  end
end

# TODO: 1. データベース接続問題の追跡システムと自動レポート - docs/guides/test_stability.mdを参照
# TODO: 2. CI環境でのテストデータベース設定最適化 - テストパフォーマンス向上のため
# TODO: 3. テストスイート実行時間の短縮 - 部分的スキーマロード導入を検討
# TODO: 4. Rails 9互換性の事前確認 - Rails.gem_version.segments.firstを使った分岐を検討
# TODO: 5. 不要になったbootstrapコードの廃止 - Rails標準のdb:prepareに統合検討
# TODO: 6. Rails 8のMigration API変更対応 - マイグレーションAPIの変更に対応
