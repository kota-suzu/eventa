# 既存の内容を維持して、以下のgemを追加します

group :development, :test do
  # 既存のgemはそのままで、以下を追加
  gem 'rspec-rails', '~> 6.1'
  gem 'factory_bot_rails', '~> 6.2'
  gem 'faker', '~> 3.1'
end

group :test do
  # テストカバレッジ計測用
  gem 'simplecov', '~> 0.22.0', require: false
  gem 'simplecov-lcov', '~> 0.8.0', require: false

  # システムテスト用
  gem 'capybara', '~> 3.39'
  gem 'selenium-webdriver', '~> 4.9'
  gem 'webdrivers', '~> 5.2'
  
  # リクエストスタブ用
  gem 'webmock', '~> 3.18'
  
  # モック・スタブ用
  gem 'rspec-mocks', '~> 3.12'
  
  # テスト時間固定用
  gem 'timecop', '~> 0.9.6'
  
  # テストデータ生成用
  gem 'database_cleaner-active_record', '~> 2.1'
end 