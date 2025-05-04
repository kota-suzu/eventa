# This file is copied to spec/ when you run 'rails generate rspec:install'
require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"
# Add additional requires below this line. Rails is not loaded until this point!
require "factory_bot_rails"

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
  # DatabaseCleaner を採用するので false にする
  config.use_transactional_fixtures = false

  # FactoryBotの設定
  config.include FactoryBot::Syntax::Methods

  # テスト実行前に一度だけファクトリを定義
  config.before(:suite) do
    puts "テスト開始時にインメモリでファクトリを定義します"

    # 既存のファクトリをクリア（重複登録を防止）
    if FactoryBot.respond_to?(:factories)
      FactoryBot.factories.clear
    end

    # 明示的にファクトリを定義
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

# Shoulda Matchersの設定
if defined?(Shoulda::Matchers)
  Shoulda::Matchers.configure do |config|
    config.integrate do |with|
      with.test_framework :rspec
      with.library :rails
    end
  end
end
