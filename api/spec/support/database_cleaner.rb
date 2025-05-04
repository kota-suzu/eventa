require "database_cleaner/active_record"

RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end

  # 並行テスト用の特別設定
  config.before(:each, :concurrent) do
    # 並行テストではトランザクションを使わず完全にクリーンアップする
    DatabaseCleaner.strategy = :truncation

    # MySQLのロックタイムアウトを増やす（デフォルトは50秒）
    ActiveRecord::Base.connection.execute("SET innodb_lock_wait_timeout = 15")
  end

  config.after(:each, :concurrent) do
    # テスト後は元のtransaction戦略に戻す
    DatabaseCleaner.strategy = :transaction

    # タイムアウト設定をデフォルトに戻す
    ActiveRecord::Base.connection.execute("SET innodb_lock_wait_timeout = 50")
  end
end
