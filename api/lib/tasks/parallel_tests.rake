# frozen_string_literal: true

namespace :parallel do
  desc "並列テスト用のテストDBをセットアップする"
  task setup: :environment do
    require "parallel_tests"

    # 並列テスト用のDBを作成
    Rake::Task["parallel:create"].invoke

    # 並列テスト用のDBを準備
    Rake::Task["parallel:prepare"].invoke
  end

  desc "並列テスト用のDBを作成"
  task create: :environment do
    # 設定をロード
    configs = ActiveRecord::Base.configurations
    test_config = configs.configs_for(env_name: Rails.env)

    # DBホスト情報を取得
    adapter = test_config.configuration_hash[:adapter]
    database = test_config.configuration_hash[:database]
    username = test_config.configuration_hash[:username]
    password = test_config.configuration_hash[:password]
    host = test_config.configuration_hash[:host]
    port = test_config.configuration_hash[:port]

    # プロセッサ数分のDBを作成
    processor_count = ENV["PARALLEL_TEST_PROCESSORS"] || Etc.nprocessors
    processor_count.to_i.times do |i|
      parallel_db_name = "#{database}_#{i + 1}"
      puts "Creating database #{parallel_db_name}"

      # MySQLの場合
      if adapter.include?("mysql")
        mysql_command = "mysql -u #{username} -p#{password} -h #{host} -P #{port} -e 'CREATE DATABASE IF NOT EXISTS #{parallel_db_name};'"
        system mysql_command
      end
    end
  end

  desc "並列テスト用のDBをマイグレーション"
  task prepare: :environment do
    require "parallel_tests"

    # 並列テスト用にスキーマをロード
    Rake::Task["parallel:load_schema"].invoke
  end

  desc "並列テスト用のスキーマをロード"
  task load_schema: :environment do
    # 設定をロード
    configs = ActiveRecord::Base.configurations
    test_config = configs.configs_for(env_name: Rails.env)

    # DBホスト情報を取得
    database = test_config.configuration_hash[:database]

    # プロセッサ数分のDBにスキーマをロード
    processor_count = ENV["PARALLEL_TEST_PROCESSORS"] || Etc.nprocessors
    processor_count.to_i.times do |i|
      parallel_db_name = "#{database}_#{i + 1}"
      puts "Loading schema for #{parallel_db_name}"

      # 環境変数を一時的に変更してRidgepoleを実行
      env_backup = {}
      ENV.to_h.select { |k, _| k.start_with?("DB_") }.each do |k, v|
        env_backup[k] = v
      end

      begin
        ENV["DB_NAME"] = parallel_db_name
        # Ridgepoleを使用する場合
        if File.exist?("#{Rails.root}/db/Schemafile")
          system "RAILS_ENV=test bundle exec ridgepole -c config/database.yml -E test --apply -f db/Schemafile"
        else
          # 通常のマイグレーションを使用する場合
          system "RAILS_ENV=test bundle exec rake db:schema:load DB_NAME=#{parallel_db_name}"
        end
      ensure
        # 環境変数を元に戻す
        env_backup.each { |k, v| ENV[k] = v }
      end
    end
  end

  desc "並列RSpecテストを実行"
  task :spec, [:files] => :environment do |_, args|
    files = args[:files] || "spec"
    command = "bundle exec parallel_rspec #{files}"
    puts "Running: #{command}"
    system command
  end
end
