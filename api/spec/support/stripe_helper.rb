# frozen_string_literal: true

RSpec.configure do |config|
  config.before(:suite) do
    # テスト開始前に一度だけStripeモックを設定
    Mocks::StripeMock.setup
  end

  config.after(:suite) do
    # テスト終了後にモックを解除
    Mocks::StripeMock.teardown
  end
end
