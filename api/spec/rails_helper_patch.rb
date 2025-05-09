# frozen_string_literal: true

# このファイルはrails_helper.rbの先頭で読み込まれるパッチファイルです
# テスト環境でのクレデンシャル関連の問題を回避するための設定を含みます

# テスト環境専用の設定
if ENV["RAILS_ENV"] == "test"
  puts "テスト環境パッチを適用します"

  # クレデンシャル無効化
  ENV["RAILS_MASTER_KEY"] = "0123456789abcdef0123456789abcdef"
  ENV["SECRET_KEY_BASE"] = "test_secret_key_base_for_safe_testing_only"

  # ActiveRecord暗号化の固定キー
  ENV["RAILS_ENCRYPTION_PRIMARY_KEY"] = "00000000000000000000000000000000"
  ENV["RAILS_ENCRYPTION_DETERMINISTIC_KEY"] = "11111111111111111111111111111111"
  ENV["RAILS_ENCRYPTION_KEY_DERIVATION_SALT"] = "2222222222222222222222222222222222222222222222222222222222222222"

  # JWT設定
  ENV["JWT_SECRET_KEY"] = "test_jwt_secret_key_for_tests_only"
  ENV["JWT_EXPIRATION"] = "3600" # 1時間

  # credentialsの挙動をモンキーパッチ
  module TestCredentialsOverride
    def credentials
      @test_credentials ||= Class.new do
        def secret_key_base
          "test_secret_key_base_for_safe_testing_only"
        end

        def method_missing(method_name, *args)
          # credentialsの値をテスト用に固定
          return "test_value" if method_name.to_s.end_with?("_key")
          return {} if method_name.to_s == "config"
          super
        end

        def respond_to_missing?(method_name, include_private = false)
          method_name.to_s.end_with?("_key") || method_name.to_s == "config" || super
        end
      end.new
    end
  end

  # テスト開始前にパッチを適用
  require "rails/application"
  Rails::Application.prepend(TestCredentialsOverride)

  # ActiveRecord::Encryptionの設定をテスト用に上書き
  module ActiveRecordEncryptionConfigOverride
    def encryption
      @test_encryption_config ||= Class.new do
        attr_accessor :primary_key, :deterministic_key, :key_derivation_salt,
          :support_unencrypted_data, :extend_queries

        def initialize
          @primary_key = "00000000000000000000000000000000"
          @deterministic_key = "11111111111111111111111111111111"
          @key_derivation_salt = "2222222222222222222222222222222222222222222222222222222222222222"
          @support_unencrypted_data = true
          @extend_queries = true
        end
      end.new
    end
  end

  # テスト環境のみパッチを適用
  if defined?(ActiveRecord::Base)
    ActiveRecord::Base.singleton_class.prepend(ActiveRecordEncryptionConfigOverride)
  end

  puts "✓ テスト環境の安全パッチを適用しました"
end
