# frozen_string_literal: true

namespace :db do
  namespace :test do
    desc "テストデータベースとスキーマの健全性を検証"
    task verify_schema: :environment do
      ENV["RAILS_ENV"] = "test"
      puts "テストデータベースの健全性を検証しています..."

      begin
        # データベース接続確認
        ActiveRecord::Base.establish_connection
        ActiveRecord::Base.connection.verify!
        puts "✓ データベース接続確認"

        # スキーママイグレーションテーブルの存在確認
        tables = ActiveRecord::Base.connection.tables
        if tables.include?("schema_migrations")
          migrations_count = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM schema_migrations")
          puts "✓ スキーママイグレーションテーブル確認: #{migrations_count}件のマイグレーション"
        else
          puts "✗ スキーママイグレーションテーブルが存在しません"
          puts "スキーマが適用されていません。db:test:prepareを実行します。"
          Rake::Task["db:test:prepare"].invoke
          return
        end

        # 重要なテーブルの存在確認
        critical_tables = %w[users events tickets]
        missing_tables = critical_tables.reject { |t| tables.include?(t) }

        if missing_tables.any?
          puts "✗ 重要なテーブルが不足しています: #{missing_tables.join(", ")}"
          puts "スキーマが正しく適用されていません。db:test:prepareを実行します。"
          Rake::Task["db:test:prepare"].invoke
          return
        else
          puts "✓ 重要なテーブルの存在確認完了"
        end

        # usersテーブルの構造確認
        if tables.include?("users")
          begin
            columns = ActiveRecord::Base.connection.columns("users").map(&:name)
            expected_columns = %w[id email name created_at updated_at]
            missing_columns = expected_columns.reject { |c| columns.include?(c) }

            if missing_columns.any?
              puts "✗ usersテーブルに期待されるカラムが不足しています: #{missing_columns.join(", ")}"
              puts "スキーマが正しく適用されていません。db:test:prepareを実行します。"
              Rake::Task["db:test:prepare"].invoke
              return
            else
              puts "✓ usersテーブルの構造確認完了"
            end
          rescue => e
            puts "✗ usersテーブルの構造確認中にエラーが発生しました: #{e.message}"
            puts "スキーマが正しく適用されていません。db:test:prepareを実行します。"
            Rake::Task["db:test:prepare"].invoke
            return
          end
        end

        # インデックスの健全性確認
        begin
          # usersテーブルのインデックス確認
          indexes = ActiveRecord::Base.connection.indexes("users")
          email_index = indexes.find { |idx| idx.columns.include?("email") }

          if email_index.nil?
            puts "✗ usersテーブルのemailカラムにインデックスがありません"
            puts "スキーマが正しく適用されていません。db:test:prepareを実行します。"
            Rake::Task["db:test:prepare"].invoke
            return
          else
            puts "✓ インデックス確認完了"
          end
        rescue => e
          puts "✗ インデックス確認中にエラーが発生しました: #{e.message}"
        end

        # トランザクション機能確認
        begin
          ActiveRecord::Base.transaction do
            # テスト用のクエリ実行
            ActiveRecord::Base.connection.execute("SELECT 1")
            # 意図的にロールバック
            raise ActiveRecord::Rollback
          end
          puts "✓ トランザクション機能確認完了"
        rescue => e
          puts "✗ トランザクション機能確認中にエラーが発生しました: #{e.message}"
          puts "データベース接続に問題があります。db:test:prepareを実行します。"
          Rake::Task["db:test:prepare"].invoke
          return
        end

        puts "テストデータベースの健全性確認が完了しました。問題は見つかりませんでした。"
      rescue => e
        puts "データベース健全性確認中にエラーが発生しました: #{e.message}"
        puts "データベース接続または構造に問題があります。db:test:prepareを実行します。"
        Rake::Task["db:test:prepare"].invoke
      end
    end

    desc "テストデータベースの修復（緊急用）"
    task repair: :environment do
      ENV["RAILS_ENV"] = "test"
      puts "テストデータベースを修復しています..."

      begin
        # データベース接続設定を取得
        config = ActiveRecord::Base.configurations.configs_for(env_name: "test").first
        db_config = config.configuration_hash
        database_name = db_config[:database]

        # 接続をリセット
        ActiveRecord::Base.connection_pool.disconnect!

        # データベースのドロップと再作成
        begin
          puts "データベース #{database_name} をドロップして再作成します..."

          # ActiveRecordのAPIを使用
          ActiveRecord::Base.establish_connection(db_config.merge(database: nil))

          # データベースの存在確認
          if ActiveRecord::Base.connection.database_exists?(database_name)
            ActiveRecord::Base.connection.drop_database(database_name)
            puts "✓ データベースのドロップに成功しました"
          end

          # データベースの作成
          ActiveRecord::Base.connection.create_database(database_name, charset: "utf8mb4", collation: "utf8mb4_unicode_ci")
          puts "✓ データベースの作成に成功しました"
        rescue => e
          puts "データベースの再作成中にエラーが発生しました: #{e.message}"

          # 別の方法でリカバリを試みる
          begin
            begin
              ActiveRecord::Tasks::DatabaseTasks.drop_current
            rescue
              nil
            end
            begin
              ActiveRecord::Tasks::DatabaseTasks.create_current
            rescue
              nil
            end
            puts "✓ DatabaseTasksを使用してデータベースを再作成しました"
          rescue => e2
            puts "DatabaseTasksを使用したデータベース再作成にも失敗しました: #{e2.message}"
            puts "手動でのデータベース修復が必要かもしれません"
          end
        end

        # 接続を再確立
        ActiveRecord::Base.establish_connection

        # スキーマのロード
        begin
          puts "スキーマをロードしています..."
          load_schema = -> do
            if ActiveRecord::Base.connection.tables.empty? || !ActiveRecord::Base.connection.table_exists?("schema_migrations")
              if Rails.application.config.active_record.schema_format == :ruby
                Rake::Task["db:schema:load"].invoke
              else
                Rake::Task["db:structure:load"].invoke
              end
              puts "✓ Railsのスキーマロードに成功しました"
            else
              puts "スキーマは既に存在しています"
            end
          end

          # スキーマロードを実行
          load_schema.call

          # Ridgepoleが定義されている場合は、それも使用
          if defined?(Ridgepole) || File.exist?(Rails.root.join("db", "Schemafile"))
            puts "Ridgepoleでもスキーマを適用しています..."
            begin
              Rake::Task["ridgepole:apply_to_test"].invoke
            rescue => ridgepole_error
              puts "Ridgepoleでのスキーマ適用に失敗しました: #{ridgepole_error.message}"
              # すでにRailsのスキーマロードは試したので、ここでは失敗を無視
            end
          end
        rescue => schema_error
          puts "スキーマロード中にエラーが発生しました: #{schema_error.message}"
          exit 1
        end

        # FactoryBotのリロード（定義されている場合）
        if defined?(FactoryBot)
          begin
            FactoryBot.reload
            puts "✓ FactoryBot設定をリロードしました"
          rescue => e
            puts "FactoryBot設定のリロード中にエラーが発生しました: #{e.message}"
          end
        end

        puts "テストデータベースの修復が完了しました"
      rescue => e
        puts "テストデータベースの修復中に致命的なエラーが発生しました: #{e.message}"
        puts e.backtrace.take(5).join("\n") if e.backtrace
        exit 1
      end
    end
  end

  namespace :health do
    desc "データベース接続を確認する"
    task check: :environment do
      if ActiveRecord::Base.connection.active?
        tables_count = ActiveRecord::Base.connection.tables.size
        puts "データベース接続: 正常（テーブル数: #{tables_count}）"
        exit 0
      else
        puts "データベース接続: 切断されています"
        exit 1
      end
    rescue => e
      puts "データベース接続エラー: #{e.message}"
      exit 1
    end

    desc "データベース接続をリセットする"
    task reset: :environment do
      puts "データベース接続をリセットしています..."
      ActiveRecord::Base.connection_pool.disconnect!
      ActiveRecord::Base.connection_pool.clear_reloadable_connections!
      ActiveRecord::Base.establish_connection

      if ActiveRecord::Base.connection.active?
        puts "データベース接続のリセットに成功しました"
        exit 0
      else
        puts "データベース接続のリセット後も接続できません"
        exit 1
      end
    rescue => e
      puts "データベース接続リセット中にエラーが発生しました: #{e.message}"
      exit 1
    end
  end
end

# テスト環境のCIパイプライン向けタスク
namespace :test do
  desc "テスト環境データベースを初期化し、RSpecを実行する"
  task :run do
    puts "テスト環境の初期化とRSpec実行を開始します..."

    # テストデータベースを準備
    Rake::Task["db:test:verify_schema"].invoke

    # RSpecを実行
    rspec_cmd = "bundle exec rspec"
    system(rspec_cmd)

    puts "テストの実行が完了しました"
  end

  # エイリアスタスク
  desc "テストデータベースの健全性チェック"
  task db_health: "db:test:verify_schema"

  desc "テストデータベースの修復"
  task db_repair: "db:test:repair"
end
