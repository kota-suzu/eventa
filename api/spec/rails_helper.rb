# This file is copied to spec/ when you run 'rails generate rspec:install'
require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"
# Add additional requires below this line. Rails is not loaded until this point!
require "factory_bot_rails"
require "shoulda/matchers"

# Shoulda Matchersの設定 - ファイル先頭に移動して確実に初期化
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
Dir[Rails.root.join("spec", "support", "**", "*.rb")].sort.each { |f| require f }

# Checks for pending migrations and applies them before tests are run.
# If you are not using ActiveRecord, you can remove these lines.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  # Rails 8.0では fixtures の設定方法が変更されています
  # この設定は必要ない場合は削除します
  # config.fixtures_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  # トランザクション使用に戻して高速化
  config.use_transactional_fixtures = true

  # FactoryBotの設定
  config.include FactoryBot::Syntax::Methods

  # ファクトリの初期化は一度だけ実行
  unless defined?(FACTORY_BOT_LOADED)
    config.before(:suite) do
      puts "FactoryBot初期化設定が適用されました"
    end

    # 既存のファクトリをクリア
    FactoryBot.factories.clear if FactoryBot.factories.collect(&:name).include?(:user)

    # ファクトリを明示的に定義
    FactoryBot.define do
      factory :user do
        sequence(:email) { |n| "user#{n}@example.com" }
        password { "password123" }
        password_confirmation { "password123" }
        name { "Test User" }
        role { "guest" }

        factory :organizer, parent: :user do
          role { "organizer" }
        end
      end

      factory :event do
        sequence(:title) { |n| "Event #{n}" }
        sequence(:description) { |n| "Description for event #{n}" }
        start_at { 1.day.from_now }
        end_at { 2.days.from_now }
        venue { "Test Venue" }
        capacity { 100 }
        is_public { true }
        association :user, factory: :organizer
      end

      factory :ticket do
        sequence(:title) { |n| "Ticket #{n}" }
        description { "Standard ticket for the event" }
        price { 1000 }
        quantity { 100 }
        available_quantity { 100 }
        association :event
      end

      factory :reservation do
        quantity { 1 }
        status { "pending" }
        payment_method { "credit_card" }
        association :user
        association :ticket
      end
    end

    FACTORY_BOT_LOADED = true
  end

  # DatabaseCleanerの設定を単純化
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  # 並行テスト用のみ特別戦略を適用
  config.before(:each, :concurrent) do
    DatabaseCleaner.strategy = :truncation
  end

  config.after(:each, :concurrent) do
    # テスト後は元のtransaction戦略に戻す
    DatabaseCleaner.strategy = :transaction
  end

  # テストパフォーマンス改善: CIモードではプロファイリングを無効化
  config.profile_examples = ENV["CI"] ? 0 : 10

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
end
