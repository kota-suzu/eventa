# frozen_string_literal: true

# Shoulda Matchers設定
require "shoulda-matchers"

# RSpec用にShoulda Matchersを設定
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

# RSpecがShouldaヘルパーを使用できるようにする
RSpec.configure do |config|
  config.include Shoulda::Matchers::ActiveModel
  config.include Shoulda::Matchers::ActiveRecord
end
