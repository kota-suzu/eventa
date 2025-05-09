# frozen_string_literal: true

# credentials_patch.rb - テスト環境でのRails.applicationのcredentialsへのアクセスに対するモンキーパッチ
# 主にActiveSupport::MessageEncryptor::InvalidMessageエラーを解決します

# 必要な環境変数をデフォルト値で設定（Railsの読み込み前でも安全）
ENV["RAILS_ENV"] ||= "test"
ENV["RAILS_MASTER_KEY"] ||= "0123456789abcdef0123456789abcdef"
ENV["SECRET_KEY_BASE"] ||= "test_secret_key_base_for_safe_testing_only"
ENV["JWT_SECRET_KEY"] ||= "test_jwt_secret_key_for_tests_only"
ENV["RAILS_ENCRYPTION_PRIMARY_KEY"] ||= "00000000000000000000000000000000"
ENV["RAILS_ENCRYPTION_DETERMINISTIC_KEY"] ||= "11111111111111111111111111111111"
ENV["RAILS_ENCRYPTION_KEY_DERIVATION_SALT"] ||= "2222222222222222222222222222222222222222222222222222222222222222"
ENV["GIT_DISCOVERY_ACROSS_FILESYSTEM"] ||= "1"

# Railsモニキーパッチの適用を遅延実行する（Rails環境が読み込まれた後で適用）
module TestEnvironmentCredentialsPatch
  # テスト環境用のデフォルト認証情報
  TEST_CREDENTIALS = {
    # JWT認証用の設定
    jwt_secret: ENV.fetch("JWT_SECRET_KEY", "test_jwt_secret_key_for_tests_only"),
    jwt_issuer: "eventa-api-test",
    jwt_audience: "eventa-test-client",

    # ActiveRecord::Encryption用の設定
    active_record: {
      encryption: {
        primary_key: ENV.fetch("RAILS_ENCRYPTION_PRIMARY_KEY", "00000000000000000000000000000000"),
        deterministic_key: ENV.fetch("RAILS_ENCRYPTION_DETERMINISTIC_KEY", "11111111111111111111111111111111"),
        key_derivation_salt: ENV.fetch("RAILS_ENCRYPTION_KEY_DERIVATION_SALT", "2222222222222222222222222222222222222222222222222222222222222222")
      }
    },

    # 一般的な設定
    secret_key_base: ENV.fetch("SECRET_KEY_BASE", "test_secret_key_base_for_safe_testing_only"),

    # Stripe関連の設定
    stripe: {
      publishable_key: "pk_test_sample_key_123456",
      secret_key: "sk_test_sample_key_123456",
      webhook_secret: "whsec_test_sample_key_123456"
    }
  }

  # Rails.applicationモンキーパッチを適用（テスト環境用）
  module DisableCredentialsForTest
    def credentials
      # ActiveSupport::HashWithIndifferentAccessを使用してdigメソッドを提供
      @test_credentials ||= if defined?(ActiveSupport::HashWithIndifferentAccess)
        TEST_CREDENTIALS.deep_dup.with_indifferent_access
      else
        # ActiveSupportがロードされていない場合のフォールバック
        test_hash = TEST_CREDENTIALS.deep_dup

        # digメソッドを動的に実装
        def test_hash.dig(*keys)
          keys.reduce(self) do |memo, key|
            return nil unless memo.is_a?(Hash) && memo.has_key?(key)
            memo[key]
          end
        end

        # method_missingで未定義のキーに対応
        def test_hash.method_missing(method_name, *args)
          if method_name.to_s.end_with?("_key")
            # キー関連のプロパティには安全な固定値を返す
            "test_#{method_name}_for_tests_only"
          elsif method_name.to_s == "config"
            # configに対しては空のハッシュを返す
            {}
          else
            super
          end
        end

        # respond_to?でmethod_missingの対象も反映
        def test_hash.respond_to_missing?(method_name, include_private = false)
          method_name.to_s.end_with?("_key") || method_name.to_s == "config" || super
        end

        test_hash
      end
    end
  end

  # データベースローダーのモンキーパッチ（必要に応じて）
  module SkipCredentialsForDatabaseTasks
    def check_protected_environments!
      # テスト環境では保護環境チェックをスキップ
      return if Rails.env.test?
      super
    end
  end

  # 遅延設定（Rails環境ロード後に実行）
  def self.apply_patches
    # Rails.applicationが存在し、テスト環境の場合のみ適用
    return unless defined?(Rails) && defined?(Rails.application) && Rails.env.test?

    begin
      # Railsのcredentialsをパッチする
      Rails.application.singleton_class.prepend(DisableCredentialsForTest)
      puts "✓ Rails.application.credentialsに安全なパッチを適用しました"

      # DatabaseTasksをパッチする（存在する場合）
      if defined?(ActiveRecord::Tasks::DatabaseTasks)
        ActiveRecord::Tasks::DatabaseTasks.singleton_class.prepend(SkipCredentialsForDatabaseTasks)
        puts "✓ DatabaseTasksにパッチを適用しました"
      end

      # ActiveRecord暗号化の設定（Rails.application.configが利用可能な場合のみ）
      if defined?(ActiveRecord::Encryption) && defined?(Rails.application.config)
        Rails.application.config.active_record.encryption.primary_key = ENV.fetch("RAILS_ENCRYPTION_PRIMARY_KEY", "00000000000000000000000000000000")
        Rails.application.config.active_record.encryption.deterministic_key = ENV.fetch("RAILS_ENCRYPTION_DETERMINISTIC_KEY", "11111111111111111111111111111111")
        Rails.application.config.active_record.encryption.key_derivation_salt = ENV.fetch("RAILS_ENCRYPTION_KEY_DERIVATION_SALT", "2222222222222222222222222222222222222222222222222222222222222222")
        Rails.application.config.active_record.encryption.support_unencrypted_data = true
        Rails.application.config.active_record.encryption.extend_queries = true
        puts "✓ ActiveRecordの暗号化設定を適用しました"
      end
    rescue => e
      puts "⚠️ テスト環境のセットアップに失敗しました: #{e.message}"
      puts e.backtrace.join("\n")[0..500] if e.backtrace
    end
  end
end

# 必要に応じてパッチを適用する準備（Rails環境が読み込まれた後）
if ENV["RAILS_ENV"] == "test"
  if defined?(Rails)
    # Rails定数が既に存在する場合は直接パッチ適用
    TestEnvironmentCredentialsPatch.apply_patches
  else
    # Rails定数がまだ存在しない場合はパッチ適用を遅延して行う
    # 設定：環境読み込み後の初回実行
    at_exit do
      # Rails定数が存在するようになった場合のみパッチを適用する
      TestEnvironmentCredentialsPatch.apply_patches if defined?(Rails)
    end

    puts "📌 テスト環境用の認証情報パッチが登録されました（Rails環境ロード後に適用）"
  end
end
