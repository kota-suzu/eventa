# frozen_string_literal: true

# This file is copied to spec/ when you run 'rails generate rspec:install'
require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?

require "rspec/rails"

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories.
Dir[Rails.root.join("spec", "support", "**", "*.rb")].sort.each { |f| require f }

# FactoryBotの定義はfactory_bot.rbですでにロードされているため、ここでは不要
# FactoryBot.find_definitions

# Checks for pending migrations and applies them before tests are run.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # You can uncomment this line to turn off ActiveRecord support entirely.
  # config.use_active_record = false

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, type: :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://rspec.info/features/6-0/rspec-rails
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")

  # Shoulda Matchers
  Shoulda::Matchers.configure do |shoulda_config|
    shoulda_config.integrate do |with|
      with.test_framework :rspec
      with.library :rails
    end
  end

  # ActiveSupport::Testing::TimeHelpers
  config.include ActiveSupport::Testing::TimeHelpers

  # モデルテスト高速化のためのオプション設定
  config.before(:each, type: :model) do
    ActiveRecord::Base.logger.level = Logger::INFO
  end

  # テストが失敗した時に詳細情報を出力
  config.after(:each) do |example|
    if example.exception
      puts "\nTest failed: #{example.full_description}"
      puts "Exception: #{example.exception.class} - #{example.exception.message}"
    end
  end

  # フィルタ設定
  config.filter_run_when_matching :focus
  config.run_all_when_everything_filtered = true

  # テスト実行順序をランダム化
  config.order = :random
end
