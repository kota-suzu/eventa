# frozen_string_literal: true

# データベース接続の問題を解決するためのヘルパー
module TestDBConnectionHelper
  # 接続再試行機能付きでデータベース接続を確立
  # @param max_attempts [Integer] 最大試行回数
  # @param retry_wait [Float] 再試行の間隔（秒）
  def self.ensure_connection(max_attempts: 3, retry_wait: 1.5)
    attempts = 0
    begin
      attempts += 1
      # 接続を確認
      ActiveRecord::Base.connection_pool.with_connection do |conn|
        conn.execute("SELECT 1")
      end
      puts "✓ データベース接続確認完了"
      true
    rescue => e
      if attempts < max_attempts
        # 失敗情報を出力
        puts "! データベース接続エラー（#{attempts}/#{max_attempts}）: #{e.message}"
        puts "  #{retry_wait}秒後に再試行します..."
        sleep retry_wait
        retry
      else
        puts "✗ データベース接続に失敗しました（#{max_attempts}回試行）"
        puts "  エラー詳細: #{e.class} - #{e.message}"
        if defined?(Rails) && Rails.logger
          Rails.logger.error("データベース接続エラー: #{e.message}")
          Rails.logger.error(e.backtrace.join("\n")) if e.backtrace
        end
        false
      end
    end
  end

  # テストデータベース用のテーブル状態チェック
  def self.verify_test_tables
    puts "テスト用テーブルの検証を開始..."
    begin
      # 重要なテーブルの存在確認
      critical_tables = %w[events users tickets ticket_types participants reservations]
      existing_tables = ActiveRecord::Base.connection.tables
      missing_tables = critical_tables - existing_tables

      if missing_tables.empty?
        puts "✓ 重要テーブルは全て存在します"
      else
        puts "! 不足テーブル: #{missing_tables.join(", ")}"
        puts "  現在のテーブル: #{existing_tables.join(", ")}"
        return false
      end

      # usersテーブルの構造確認（最低限のカラムチェック）
      if existing_tables.include?("users") && ActiveRecord::Base.connection.column_exists?(:users, :email)
        puts "✓ usersテーブル構造確認OK"
      else
        puts "! usersテーブルの構造に問題があります"
        return false
      end

      true
    rescue => e
      puts "✗ テーブル検証中にエラーが発生しました: #{e.message}"
      false
    end
  end
end

# RSpecに読み込まれたときの初期化処理
if defined?(RSpec)
  puts "データベース接続ヘルパーを初期化しています..."

  # テスト環境で自動的に接続確認を実行
  RSpec.configure do |config|
    config.before(:suite) do
      # 接続確認 - 失敗したら再作成を試行
      unless TestDBConnectionHelper.ensure_connection
        puts "データベース接続を再確立します..."
        begin
          # テスト用データベース再作成とスキーマ適用の試行
          require "rake"
          Rails.application.load_tasks

          puts "テスト用データベースを再作成しています..."
          begin
            Rake::Task["db:drop"].invoke if ActiveRecord::Base.connection.data_source_exists?("schema_migrations")
          rescue
            nil
          end
          Rake::Task["db:create"].invoke

          # Ridgepoleが利用可能ならそれを使ってスキーマを適用
          if defined?(Ridgepole)
            puts "Ridgepoleを使ってスキーマを適用しています..."
            system("bundle exec ridgepole -c config/database.yml -E test --apply -f db/Schemafile")
          else
            puts "Activerecordを使ってスキーマを適用しています..."
            Rake::Task["db:schema:load"].invoke
          end

          # 再度接続確認
          unless TestDBConnectionHelper.ensure_connection
            abort "テストデータベースの再作成に失敗しました。手動での対応が必要です。"
          end
        rescue => e
          abort "テストデータベースの再作成中にエラーが発生しました: #{e.message}"
        end
      end

      # テーブルの検証
      unless TestDBConnectionHelper.verify_test_tables
        puts "! テストデータベースに問題があります。手動での修復が必要な可能性があります。"
        puts "  'make repair-test-db' を実行してください。"
      end
    end
  end
end

# TODOリスト
# TODO: 1. データベースタイムアウト設定の調整 - 本番環境のステータスモニタリングで解決済み
# TODO: 2. コネクションプールサイズの最適化 - 連続API撮影時のパフォーマンス向上で確認済み
# TODO: 3. 水平スケーリング時のコネクション管理戦略の検討 - docs/guides/scaling.mdを参照
