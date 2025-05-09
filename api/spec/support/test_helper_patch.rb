# frozen_string_literal: true

# テスト環境でのRails.applicationモンキーパッチ（credentialsを無効化）
module DisableCredentialsForTestEnv
  # credentialsへのアクセスを無効化して固定値を返すようにするモンキーパッチを定義
  def credentials
    return nil unless Rails.env.test?

    # テスト環境では@credentials_disabledをシングルトンとして使用
    @credentials_disabled ||= Class.new do
      def secret_key_base
        "test_secret_key_base_for_safe_testing_only"
      end

      def jwt_secret
        "test_jwt_secret_for_safe_testing_only"
      end

      def jwt_issuer
        "eventa-api-test"
      end

      def jwt_audience
        "eventa-test-client"
      end

      # nilではなく空文字列を返すメソッド
      def method_missing(method_name, *args)
        return "" if method_name.to_s.end_with?("_key")
        return {} if method_name.to_s == "config"
        super
      end

      def respond_to_missing?(method_name, include_private = false)
        method_name.to_s.end_with?("_key") || method_name.to_s == "config" || super
      end
    end.new
  end
end

if Rails.env.test?
  Rails.application.singleton_class.prepend(DisableCredentialsForTestEnv)
  puts "✓ Rails.application.credentialsをテスト環境用に安全にパッチしました"

  # 環境変数も設定（モデル暗号化のために必要）
  # これらのキーはテスト環境でのみ使用されるもので安全です
  ENV["RAILS_MASTER_KEY"] = "0123456789abcdef0123456789abcdef"
  ENV["SECRET_KEY_BASE"] = "test_secret_key_base_for_safe_testing_only"

  # ActiveRecord::Encryption用のキーも環境変数で設定
  ENV["RAILS_ENCRYPTION_PRIMARY_KEY"] = "00000000000000000000000000000000"
  ENV["RAILS_ENCRYPTION_DETERMINISTIC_KEY"] = "11111111111111111111111111111111"
  ENV["RAILS_ENCRYPTION_KEY_DERIVATION_SALT"] = "2222222222222222222222222222222222222222222222222222222222222222"

  puts "✓ テスト環境用の暗号化関連環境変数を設定しました"
end
