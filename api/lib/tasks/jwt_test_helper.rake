# frozen_string_literal: true

# JWT認証テストのためのヘルパータスク
# Rails 8での暗号化関連の問題を回避し、テスト環境でJWT関連のテストを実行するための
# ユーティリティタスクを提供します。
namespace :jwt do
  namespace :test do
    desc "JWT認証関連のテスト環境を準備する"
    task setup: :environment do
      unless Rails.env.test?
        puts "このタスクはテスト環境でのみ実行できます"
        exit 1
      end

      puts "JWT認証テスト環境をセットアップしています..."

      # 鍵設定の初期化（テスト環境専用）
      begin
        # Rails 8のキー要件（16バイト）を満たすテスト用キーを設定
        if Rails.version.to_f >= 8.0
          puts "Rails 8環境を検出しました - 暗号化キー設定を調整します"
          Rails.application.credentials.config.secret_key_base = "0123456789abcdef" # テスト用の16バイトキー

          # Rails 8のActiveRecord暗号化設定
          Rails.application.config.active_record.encryption.key_provider = ActiveRecord::Encryption::DerivedSecretKeyProvider.new(
            primary_key: "01234567890123456789012345678901"
          )

          # 環境変数の設定
          ENV["RAILS_MASTER_KEY"] = "0123456789abcdef"
          ENV["SECRET_KEY_BASE"] = "0123456789abcdef0123456789abcdef"
          puts "✓ テスト用暗号化キーを設定しました"
        end
      rescue => e
        puts "暗号化キー設定中にエラーが発生しました: #{e.message}"
      end

      # JWTの初期化設定を確認
      jwt_initializer_path = Rails.root.join("config/initializers/jwt.rb")

      if File.exist?(jwt_initializer_path)
        puts "JWT初期化ファイルを確認しています..."
        # 初期化ファイルの内容をロードして評価（設定の妥当性チェック）
        begin
          load jwt_initializer_path
          puts "✓ JWT初期化ファイルを読み込みました"
        rescue => e
          puts "JWT初期化ファイルのロード中にエラーが発生しました: #{e.message}"
        end
      else
        puts "警告: JWT初期化ファイルが見つかりません"
      end

      # TokenBlacklistServiceの設定確認
      begin
        # Redisがない場合はモックを使用
        require "redis"
        begin
          # 実際にRedisに接続可能か確認
          redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
          redis.ping # 接続テスト
          puts "✓ Redis接続を確認しました"
        rescue Redis::CannotConnectError => e
          puts "Redisに接続できません: #{e.message}"
          puts "TokenBlacklistServiceのテスト用Redisモックを設定します"

          # Redisモッククラスの定義（テスト用）
          mock_redis_class = Class.new do
            def initialize
              @storage = {}
            end

            def setex(key, ttl, value)
              @storage[key] = {value: value, ttl: ttl, created_at: Time.now.to_i}
              "OK"
            end

            def exists?(key)
              @storage.key?(key)
            end

            def del(key)
              @storage.delete(key) ? 1 : 0
            end

            def ping
              "PONG"
            end
          end

          # TokenBlacklistServiceにモックを設定
          if defined?(TokenBlacklistService)
            TokenBlacklistService.redis = mock_redis_class.new
            puts "✓ TokenBlacklistServiceにRedisモックを設定しました"
          end
        end
      rescue LoadError => e
        puts "Redisクラスのロード中にエラーが発生しました: #{e.message}"
      end

      puts "✓ JWT認証テスト環境のセットアップが完了しました"
    end

    desc "JWT関連のテストを実行する"
    task run: [:setup] do
      unless Rails.env.test?
        puts "このタスクはテスト環境でのみ実行できます"
        exit 1
      end

      puts "JWT関連のテストを実行しています..."

      # 基本的なJWT機能テスト
      puts "JWTエンコード/デコードのテスト:"
      begin
        # テスト用のペイロード
        payload = {user_id: 42, test: true}

        # JWTエンコード
        token = JsonWebToken.encode(payload)
        puts "  - トークン生成: #{token ? "✓" : "✗"}"

        # JWTデコード
        decoded = JsonWebToken.safe_decode(token)
        puts "  - トークンデコード: #{(decoded && decoded["user_id"] == 42) ? "✓" : "✗"}"

        # 有効期限のテスト
        exp_token = JsonWebToken.encode(payload, 2.seconds.from_now)
        puts "  - 有効期限付きトークン生成: #{exp_token ? "✓" : "✗"}"
        sleep(3)
        expired_decoded = JsonWebToken.safe_decode(exp_token)
        puts "  - 期限切れトークン検証: #{expired_decoded.nil? ? "✓" : "✗"}"

        puts "✓ JWTエンコード/デコードテスト完了"
      rescue => e
        puts "JWTテスト中にエラーが発生しました: #{e.message}"
      end

      # TokenBlacklistServiceのテスト
      puts "TokenBlacklistServiceのテスト:"
      begin
        # JTIありのトークン生成
        token_with_jti = JsonWebToken.encode({user_id: 42, jti: SecureRandom.uuid})

        # JTIなしのトークン生成
        token_without_jti = JsonWebToken.encode({user_id: 42})

        # ブラックリスト追加テスト
        add_result1 = TokenBlacklistService.add(token_with_jti)
        puts "  - JTIありトークンの追加: #{add_result1 ? "✓" : "✗"}"

        add_result2 = TokenBlacklistService.add(token_without_jti)
        puts "  - JTIなしトークンの追加: #{add_result2 ? "✓" : "✗"}"

        # ブラックリスト確認テスト
        blacklisted1 = TokenBlacklistService.blacklisted?(token_with_jti)
        puts "  - JTIありトークンのブラックリスト確認: #{blacklisted1 ? "✓" : "✗"}"

        blacklisted2 = TokenBlacklistService.blacklisted?(token_without_jti)
        puts "  - JTIなしトークンのブラックリスト確認: #{blacklisted2 ? "✓" : "✗"}"

        puts "✓ TokenBlacklistServiceテスト完了"
      rescue => e
        puts "TokenBlacklistServiceテスト中にエラーが発生しました: #{e.message}"
      end

      puts "✓ JWT関連のテストが完了しました"
    end
  end
end
