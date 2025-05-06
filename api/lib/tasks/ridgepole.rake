# frozen_string_literal: true

namespace :ridgepole do
  desc "Apply schema definition"
  task apply: :environment do
    ridgepole("--apply")
  end

  desc "Export schema definition"
  task export: :environment do
    ridgepole("--export")
  end

  desc "Show difference between schema definition and DB"
  task diff: :environment do
    ridgepole("--diff")
  end

  desc "Create a new migration file"
  task :new_migration, [:name] => :environment do |_task, args|
    unless args.name
      puts "No name specified. Use rake ridgepole:new_migration[migration_name]"
      exit 1
    end

    timestamp = Time.now.strftime("%Y%m%d%H%M%S")
    path = "db/migrations/#{timestamp}_#{args.name}.rb"

    # ディレクトリが存在しない場合は作成
    FileUtils.mkdir_p("db/migrations")

    File.write(path, <<~RUBY)
      # Migration: #{args.name}
      # Created at: #{Time.now}
      # Use this file to make changes to the Schemafile

      # Example:
      # create_table "new_table", force: :cascade do |t|
      #   t.string "name", null: false
      #   t.timestamps
      # end
      #
      # add_column "existing_table", "new_column", :string, after: "existing_column"
      #
      # To apply this migration:
      # 1. Update the Schemafile with these changes
      # 2. Run `rake ridgepole:apply`
    RUBY

    puts "Created migration file #{path}"
  end

  desc "Ridgepoleを使ってスキーマをテストデータベースに直接適用する"
  task apply_to_test: :environment do
    puts "Ridgepoleを使用してテストデータベースにスキーマを適用します..."
    ENV["RAILS_ENV"] = "test"

    # データベース設定
    config = ActiveRecord::Base.configurations.configs_for(env_name: "test").first
    db_config = config.configuration_hash

    # スキーマファイルパス
    schemafile_path = File.join(Rails.root, "db", "Schemafile")

    puts "Schemafile: #{schemafile_path}"
    puts "データベース: #{db_config[:database]}"

    # データベース接続が確立されているか確認
    begin
      ActiveRecord::Base.connection.verify!
      puts "データベース接続: ✓"
    rescue => e
      puts "データベース接続エラー: #{e.message}"
      puts "接続を再確立します..."
      ActiveRecord::Base.establish_connection
    end

    # Ridgepoleコマンドを構築
    ridgepole_options = [
      "-c", "config/database.yml",
      "-E", "test",
      "--apply",
      "-f", schemafile_path
    ]

    # 追加オプション（verbose出力など）
    ridgepole_options << "--verbose" if ENV["VERBOSE"] == "true"

    begin
      puts "Ridgepoleを実行しています..."
      require "ridgepole"

      # Ridgepoleクラスが利用可能な場合は直接オブジェクトを作成して実行
      if defined?(Ridgepole::Client)
        begin
          # 設定を直接指定する方法に変更
          config_hash = {
            adapter: db_config[:adapter],
            database: db_config[:database],
            host: db_config[:host],
            port: db_config[:port],
            username: db_config[:username],
            password: db_config[:password]
          }

          client = Ridgepole::Client.new(config_hash, config.name)
          result = client.diff(File.read(schemafile_path), exec: true)

          if result.empty?
            puts "スキーマは最新です。変更はありませんでした。"
          else
            puts "スキーマを更新しました:"
            puts result
          end
        rescue => e
          puts "Ridgepoleクライアント実行エラー: #{e.message}"
          puts "コマンドライン実行にフォールバックします..."

          # コマンドラインでridgepoleを実行
          ridgepole_cmd = "bundle exec ridgepole #{ridgepole_options.join(" ")}"
          puts "コマンド: #{ridgepole_cmd}"

          system_result = system(ridgepole_cmd)
          if system_result
            puts "Ridgepoleコマンドは正常に完了しました"
          else
            puts "Ridgepoleコマンドは失敗しました（終了コード: #{$?.exitstatus}）"
            raise "Ridgepoleコマンド実行エラー"
          end
        end
      else
        # コマンドラインでridgepoleを実行
        ridgepole_cmd = "bundle exec ridgepole #{ridgepole_options.join(" ")}"
        puts "コマンド: #{ridgepole_cmd}"

        system_result = system(ridgepole_cmd)
        if !system_result
          puts "Ridgepoleコマンドは失敗しました（終了コード: #{$?.exitstatus}）"
          raise "Ridgepoleコマンド実行エラー"
        else
          puts "Ridgepoleコマンドは正常に完了しました"
        end
      end

      # スキーマ適用後、テーブルの存在を確認
      tables = ActiveRecord::Base.connection.tables
      puts "テーブル一覧: #{tables.join(", ")}"

      missing_tables = %w[users events tickets].reject { |t| tables.include?(t) }
      if missing_tables.any?
        puts "注意: 期待されるテーブルが不足しています: #{missing_tables.join(", ")}"
        raise "スキーマ適用後も重要なテーブルが不足しています"
      else
        puts "✓ 重要なテーブルの存在を確認しました"
      end
    rescue => e
      puts "スキーマ適用中にエラーが発生しました: #{e.message}"
      puts e.backtrace.take(5).join("\n") if e.backtrace
      exit 1
    end
  end

  desc "テスト環境のスキーマをDRYラン（実行なし）でチェック"
  task dry_run: :environment do
    ENV["RAILS_ENV"] = "test"

    # Ridgepoleコマンドを構築
    ridgepole_options = [
      "-c", "config/database.yml",
      "-E", "test",
      "--apply-dry-run",
      "-f", File.join(Rails.root, "db", "Schemafile")
    ]

    # コマンド実行
    cmd = "bundle exec ridgepole #{ridgepole_options.join(" ")}"
    puts "コマンド: #{cmd}"

    system_result = system(cmd)
    exit_code = $?.exitstatus

    # 結果の処理
    if system_result
      puts "✓ スキーマは同期しています（変更なし）"
      exit 0
    else
      puts "！ スキーマの差分があります（終了コード: #{exit_code}）"
      exit exit_code
    end
  end

  desc "テスト環境のデータベーススキーマを修復する（緊急用）"
  task repair_test: :environment do
    puts "テスト環境のデータベーススキーマを修復します..."
    ENV["RAILS_ENV"] = "test"

    begin
      # テストデータベース接続設定を取得
      config = ActiveRecord::Base.configurations.configs_for(env_name: "test").first
      db_config = config.configuration_hash
      database_name = db_config[:database]

      # 接続をリセット
      ActiveRecord::Base.connection_pool.disconnect!

      # Docker Compose経由でMySQLコマンドを実行
      puts "データベース #{database_name} を再作成します..."

      # Docker Compose実行用のヘルパーメソッド
      def run_mysql_command(command)
        puts "実行するコマンド: #{command}"
        result = system(command)
        puts result ? "コマンド実行成功" : "コマンド実行失敗（終了コード: #{$?.exitstatus}）"
        result
      end

      # DBコンテナでSQLコマンドを実行
      mysql_docker_cmd = "docker-compose exec -T db mysql -u root -prootpass"

      # データベースが存在するか確認
      check_cmd = "#{mysql_docker_cmd} -e 'SHOW DATABASES LIKE \"#{database_name}\"'"
      puts "データベース存在確認..."
      check_result = `#{check_cmd}`

      if check_result.include?(database_name)
        # ドロップ
        puts "既存のデータベースをドロップします..."
        drop_cmd = "#{mysql_docker_cmd} -e 'DROP DATABASE IF EXISTS #{database_name}'"
        run_mysql_command(drop_cmd)
      end

      # 作成
      puts "データベースを作成します..."
      create_cmd = "#{mysql_docker_cmd} -e 'CREATE DATABASE #{database_name} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci'"
      unless run_mysql_command(create_cmd)
        puts "Docker経由でのデータベース作成に失敗しました。ActiveRecordを使用して再試行します..."
        # ActiveRecordを使用してデータベースを作成
        ActiveRecord::Base.establish_connection(db_config.merge(database: nil))
        ActiveRecord::Base.connection.create_database(database_name, charset: "utf8mb4", collation: "utf8mb4_unicode_ci")
        puts "ActiveRecordを使用してデータベースを作成しました"
      end

      # 接続を再確立
      puts "データベース接続を再確立します..."
      ActiveRecord::Base.establish_connection(db_config)
      if ActiveRecord::Base.connection.active?
        puts "データベース接続再確立に成功しました"
      else
        puts "データベース接続の再確立に失敗しました"
        raise "データベース接続失敗"
      end

      # Ridgepoleでスキーマを適用
      puts "Ridgepoleでスキーマを適用します..."
      Rake::Task["ridgepole:apply_to_test"].invoke

      puts "データベース修復プロセスが完了しました"
    rescue => e
      puts "データベース修復中にエラーが発生しました: #{e.message}"
      puts e.backtrace.take(5).join("\n") if e.backtrace
      exit 1
    end
  end

  desc "Ridgepoleとデータベース接続の健全性チェック"
  task healthcheck: :environment do
    ENV["RAILS_ENV"] = ENV["RAILS_ENV"] || "test"

    puts "Ridgepoleとデータベース接続の健全性チェックを実行しています..."
    puts "環境: #{ENV["RAILS_ENV"]}"

    begin
      # Ridgepoleがインストールされているか確認
      require "ridgepole"
      puts "Ridgepoleバージョン: #{Ridgepole::VERSION}"

      # データベース接続の確認
      if ActiveRecord::Base.connection.active?
        puts "データベース接続: 成功"
        puts "データベース: #{ActiveRecord::Base.connection.current_database}"
        puts "アダプタ: #{ActiveRecord::Base.connection.adapter_name}"

        # テーブル一覧
        tables = ActiveRecord::Base.connection.tables
        puts "テーブル数: #{tables.size}"
        puts "主要テーブル: #{tables.take(5).join(", ")}" if tables.any?
      else
        puts "データベース接続: 失敗"
      end

      puts "健全性チェックが完了しました"
      exit 0
    rescue => e
      puts "健全性チェックでエラーが発生しました: #{e.message}"
      puts e.backtrace.take(5).join("\n") if e.backtrace
      exit 1
    end
  end
end

# エイリアスタスク
namespace :db do
  namespace :test do
    desc "テストデータベースにスキーマを適用する（Ridgepole使用）"
    task schema_load: [:environment] do
      Rake::Task["ridgepole:apply_to_test"].invoke
    end

    desc "テストデータベースを緊急修復する"
    task emergency_repair: [:environment] do
      Rake::Task["ridgepole:repair_test"].invoke
    end
  end
end

# TODO: 1. スキーマ検証の最適化（パフォーマンス向上）
# TODO: 2. 並列テスト環境でのスキーマ適用方法の改善
# TODO: 3. Ridgepoleエラーメッセージの改善とログ集約
# TODO: 4. CI環境での自動スキーマ修復と通知メカニズム
# TODO: 5. MySQLバージョン依存の問題対応（8.0と5.7の互換性）
# TODO: 6. Dockerコンテナ間の通信とコマンド実行の安定性向上
# TODO: 7. MySQLコマンドがない環境でのフォールバック処理の強化

private

def config_file
  Rails.root.join("config/database.yml")
end

def schemafile
  Rails.root.join("db/Schemafile")
end

def ridgepole(options)
  command = "bundle exec ridgepole -c #{config_file} -E #{Rails.env} -f #{schemafile} #{options}"
  puts "[Command] #{command}"
  system(command, exception: true)
end
