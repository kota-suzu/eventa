# frozen_string_literal: true

RSpec.configure do |config|
  # 各テスト前にモックを設定
  config.before(:each) do |example|
    # 常にPaymentServiceMockを有効化
    if defined?(Mocks::PaymentServiceMock)
      Mocks::PaymentServiceMock.setup
    end

    # ReservationServiceMockは明示的に指定された場合のみ有効化
    # :reservation_service_mock => trueというメタデータが設定されている場合のみ
    if defined?(Mocks::ReservationServiceMock) && example.metadata[:reservation_service_mock] == true
      Mocks::ReservationServiceMock.setup
    end

    if defined?(Mocks::StripeMock)
      Mocks::StripeMock.setup
    end
  end

  # 各テスト後にモックを解除
  config.after(:each) do
    if defined?(Mocks::PaymentServiceMock)
      Mocks::PaymentServiceMock.teardown
    end

    if defined?(Mocks::ReservationServiceMock) && Mocks::ReservationServiceMock.already_mocked == true
      Mocks::ReservationServiceMock.teardown
    end

    if defined?(Mocks::StripeMock)
      Mocks::StripeMock.teardown
    end
  end
end
