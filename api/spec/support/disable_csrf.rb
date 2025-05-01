# テスト環境でCSRF保護を無効化
RSpec.configure do |config|
  config.before(:each, type: :request) do
    allow_any_instance_of(ActionController::Base).to receive(:protect_against_forgery?).and_return(false)
  end
end
