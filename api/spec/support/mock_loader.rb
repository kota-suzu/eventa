# frozen_string_literal: true

# テスト中に使用するモックを一元管理するためのローダー
module MockLoader
  class << self
    # すべてのモックを設定
    def setup_all
      # モックディレクトリの作成を確認
      ensure_mock_directory_exists

      # 各モックをセットアップ
      Mocks::ReservationServiceMock.setup if defined?(Mocks::ReservationServiceMock)
      Mocks::PaymentServiceMock.setup if defined?(Mocks::PaymentServiceMock)
      Mocks::Stripe.setup if defined?(Mocks::Stripe)

      # その他必要なモックがあれば追加
    end

    # すべてのモックをクリーンアップ
    def teardown_all
      Mocks::ReservationServiceMock.teardown if defined?(Mocks::ReservationServiceMock)
      Mocks::PaymentServiceMock.teardown if defined?(Mocks::PaymentServiceMock)
      Mocks::Stripe.teardown if defined?(Mocks::Stripe)

      # その他必要なモックがあれば追加
    end

    private

    # モックディレクトリの存在を確認し、ない場合は作成
    def ensure_mock_directory_exists
      mocks_dir = Rails.root.join("spec", "support", "mocks")
      Dir.mkdir(mocks_dir) unless Dir.exist?(mocks_dir)
    end
  end
end

# RSpec設定に組み込む
RSpec.configure do |config|
  # テスト実行前にすべてのモックを設定
  config.before(:suite) do
    MockLoader.setup_all
  end

  # テスト実行後にすべてのモックをクリーンアップ
  config.after(:suite) do
    MockLoader.teardown_all
  end
end
