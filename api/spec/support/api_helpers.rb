module ApiHelpers
  def json_response
    JSON.parse(response.body)
  end
end

RSpec.configure do |config|
  config.include ApiHelpers, type: :request

  config.before(:each, type: :request) do
    # Rails 7ではパラメータパーサーに関する特別な設定は不要
    # ActionController::APIはすでにCSRF保護がない
  end
end
