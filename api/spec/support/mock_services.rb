# frozen_string_literal: true

RSpec.configure do |config|
  config.before(:suite) do
    # テスト開始前にモックを設定
    if defined?(Mocks::StripeMock)
      Mocks::StripeMock.setup
    end

    if defined?(Mocks::ReservationServiceMock)
      Mocks::ReservationServiceMock.setup
    end

    if defined?(Mocks::PaymentServiceMock)
      Mocks::PaymentServiceMock.setup
    end
  end

  config.after(:suite) do
    # テスト終了後にモックを解除
    if defined?(Mocks::StripeMock)
      Mocks::StripeMock.teardown
    end

    if defined?(Mocks::ReservationServiceMock)
      Mocks::ReservationServiceMock.teardown
    end

    if defined?(Mocks::PaymentServiceMock)
      Mocks::PaymentServiceMock.teardown
    end
  end
end
