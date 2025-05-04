# frozen_string_literal: true

# テスト全般で使用するヘルパーメソッド
module TestHelpers
  # JWT トークンを生成するヘルパー
  def generate_token_for(user)
    JsonWebToken.encode({user_id: user.id})
  end

  # 認証ヘッダーを生成するヘルパー
  def auth_header(user)
    token = generate_token_for(user)
    {"Authorization" => "Bearer #{token}"}
  end

  # モックオブジェクトを作成するヘルパー
  def mock_object_with(methods = {})
    obj = Object.new
    methods.each do |method_name, return_value|
      obj.define_singleton_method(method_name) { return_value }
    end
    obj
  end
end

# RSpec に TestHelpers を追加
RSpec.configure do |config|
  config.include TestHelpers

  config.before(:suite) do
    # スイート全体で使用するグローバルなモックやスタブを設定
    StripeMock.setup if Object.const_defined?("StripeMock")
  end
end
