require "database_cleaner/active_record"

RSpec.configure do |config|
  # 全テストスイート開始前にデータベースをクリーンな状態にする
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
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

  # テスト開始前にデータベース掃除を開始
  config.before(:each) do
    DatabaseCleaner.start
  end

  # テスト完了後にデータベースを掃除
  config.after(:each) do
    DatabaseCleaner.clean
  end

  # テスト用の別々のトランザクションを処理するヘルパーメソッド
  # デッドロックのリスクを軽減するために使用
  config.around(:each, :isolate_database) do |example|
    ActiveRecord::Base.transaction do
      example.run
      raise ActiveRecord::Rollback
    end
  end
end
