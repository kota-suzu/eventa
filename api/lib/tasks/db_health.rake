# frozen_string_literal: true

namespace :db do
  namespace :health do
    desc "テスト環境のデータベース接続状態を診断"
    task check: :environment do
      require "timeout"

      def print_status(message, success = true)
        status = success ? "\e[32m✓\e[0m" : "\e[31m✗\e[0m"
        puts "#{status} #{message}"
      end

      puts "データベース接続状態の診断を開始します..."

      # 1. 基本的な接続テスト
      begin
        Timeout.timeout(5) do
          if ActiveRecord::Base.connection.active?
            print_status("基本接続テスト: 成功")
          else
            print_status("基本接続テスト: 失敗 - 接続は非アクティブ", false)
          end
        end
      rescue => e
        print_status("基本接続テスト: 失敗 - #{e.class}: #{e.message}", false)
      end

      # 2. クエリ実行テスト
      begin
        start_time = Time.now
        ActiveRecord::Base.connection.execute("SELECT 1").to_a
        execution_time = Time.now - start_time
        print_status("クエリ実行テスト: 成功 (#{execution_time.round(3)}秒)")
      rescue => e
        print_status("クエリ実行テスト: 失敗 - #{e.class}: #{e.message}", false)
      end

      # 3. 重要テーブルの存在確認
      begin
        critical_tables = %w[events users tickets ticket_types reservations]
        existing_tables = ActiveRecord::Base.connection.tables
        missing_tables = critical_tables - existing_tables

        if missing_tables.empty?
          print_status("重要テーブル確認: 成功 (全#{critical_tables.size}テーブルが存在)")
        else
          print_status("重要テーブル確認: 失敗 - 不足テーブル: #{missing_tables.join(", ")}", false)
        end
      rescue => e
        print_status("テーブル存在確認: 失敗 - #{e.class}: #{e.message}", false)
      end

      # 4. コネクションプール状態
      begin
        pool = ActiveRecord::Base.connection_pool
        print_status("コネクションプール: 最大数=#{pool.size}, 使用中=#{pool.connections.count}, 待機=#{pool.num_waiting_in_queue}")
      rescue => e
        print_status("コネクションプール確認: 失敗 - #{e.class}: #{e.message}", false)
      end

      # 5. スレッドのデッドロックチェック
      begin
        Thread.list.each_with_index do |thread, i|
          next if thread == Thread.current
          if thread.status == "sleep" && thread.backtrace && thread.backtrace.any? { |line| line.include?("mysql") }
            print_status("スレッド #{i} がデータベース操作で停止している可能性: #{thread.backtrace.first}", false)
          end
        end
      rescue => e
        print_status("スレッドチェック: 失敗 - #{e.class}: #{e.message}", false)
      end

      puts "診断完了"
    end

    desc "テスト環境のデータベース接続をリセット"
    task reset: :environment do
      puts "データベース接続をリセットしています..."

      # 使用中の接続をリリース
      ActiveRecord::Base.connection_pool.disconnect!

      # 必要に応じて再接続
      begin
        ActiveRecord::Base.connection_pool.with_connection do |conn|
          result = conn.execute("SELECT 1").to_a
          puts "✓ 接続リセット成功: #{result.inspect}"
        end
      rescue => e
        puts "✗ 接続リセット失敗: #{e.message}"
        puts "  手動による修復が必要な可能性があります。"
      end
    end

    desc "テスト用データベースを初期化"
    task initialize: :environment do
      return unless Rails.env.test?

      puts "テスト用データベースの初期化を開始..."

      begin
        # 既存のデータベースを削除
        ActiveRecord::Tasks::DatabaseTasks.drop_current
        puts "✓ 既存データベースを削除しました"
      rescue => e
        puts "! データベース削除時のエラー（無視して続行します）: #{e.message}"
      end

      begin
        # 新規データベースを作成
        ActiveRecord::Tasks::DatabaseTasks.create_current
        puts "✓ 新規データベースを作成しました"

        # Ridgepoleでスキーマを適用（利用可能な場合）
        if defined?(Ridgepole)
          puts "Ridgepoleを使ってスキーマを適用しています..."
          system("RAILS_ENV=test bundle exec ridgepole -c config/database.yml -E test --apply -f db/Schemafile")
          puts "✓ スキーマを適用しました（Ridgepole）"
        else
          # 標準的なActive Recordマイグレーション
          ActiveRecord::Tasks::DatabaseTasks.load_schema_current
          puts "✓ スキーマを適用しました（Active Record）"
        end

        # テーブル確認
        critical_tables = %w[events users tickets ticket_types reservations]
        existing_tables = ActiveRecord::Base.connection.tables
        missing_tables = critical_tables - existing_tables

        if missing_tables.empty?
          puts "✓ 全ての重要テーブルが作成されました"
        else
          puts "! 警告: 以下のテーブルが不足しています: #{missing_tables.join(", ")}"
        end
      rescue => e
        puts "✗ データベース初期化エラー: #{e.message}"
      end
    end
  end

  # 便利なショートカットコマンド
  desc "テスト環境のデータベース診断を実行"
  task test_health: "health:check"

  desc "テスト環境のデータベース接続問題を修復"
  task test_repair: ["health:reset", "health:initialize", "health:check"]
end

# TODOリスト
# TODO: 1. 接続エラーの種類に応じた対応方法のドキュメント化 - docs/guides/debugging.mdに追加予定
# TODO: 2. Dockerコンテナ再起動時のコネクションプール安全終了処理の実装
# TODO: 3. 複数サーバー環境でのデータベース接続戦略の最適化
