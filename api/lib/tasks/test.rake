namespace :test do
  desc "並列テスト実行のためのDBセットアップ"
  task parallel_prepare: :environment do
    # DBが存在しない場合は作成
    ActiveRecord::Tasks::DatabaseTasks.create_current(Rails.env)

    # スキーマのロード
    Rake::Task["db:schema:load"].invoke

    # 最大並列数
    max_workers = ENV.fetch("PARALLEL_TEST_WORKERS", Parallel.processor_count).to_i

    # テスト用データベースのコピーを作成
    (1..max_workers).each do |worker_id|
      db_name = "eventa_test#{worker_id}"
      puts "テストDB作成: #{db_name}"

      # テストDBが存在する場合は削除
      ActiveRecord::Base.connection.execute("DROP DATABASE IF EXISTS #{db_name}")

      # テストDBをコピー
      ActiveRecord::Base.connection.execute("CREATE DATABASE #{db_name}")
      ActiveRecord::Base.connection.execute("USE #{db_name}")

      # スキーマをロード
      Rake::Task["db:schema:load"].reenable
      Rake::Task["db:schema:load"].invoke
    end

    puts "並列テスト用データベース準備完了（#{max_workers}並列）"
  end

  desc "並列テスト実行"
  task :parallel do
    # 指定されたワーカー数
    workers = ENV.fetch("PARALLEL_TEST_WORKERS", Parallel.processor_count).to_i

    # データベース準備
    Rake::Task["test:parallel_prepare"].invoke

    # 引数からフォルダ/ファイルパターンを取得
    pattern = ARGV[1] || "spec/**/*_spec.rb"

    # 並列テスト実行
    system("bundle exec parallel_rspec -n #{workers} #{pattern}")

    # テスト用一時DBのクリーンアップ
    (1..workers).each do |worker_id|
      db_name = "eventa_test#{worker_id}"
      puts "テストDB削除: #{db_name}"
      ActiveRecord::Base.connection.execute("DROP DATABASE IF EXISTS #{db_name}")
    end
  end

  desc "テスト環境のメモリ使用量分析"
  task profile: :environment do
    require "memory_profiler"

    # 指定されたファイルパスを取得
    pattern = ARGV[1] || "spec/models/ticket_spec.rb"

    # メモリプロファイリング実行
    report = MemoryProfiler.report do
      system("bundle exec rspec #{pattern}")
    end

    # 結果出力
    report.pretty_print(to_file: "tmp/memory_profile.txt")
    puts "メモリプロファイリング結果: tmp/memory_profile.txt"
  end
end
