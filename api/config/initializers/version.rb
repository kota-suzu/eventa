# アプリケーションのバージョン情報を設定
# ヘルスチェックAPIで使用されます

module Eventa
  class Version
    # バージョン情報の定義
    MAJOR = 0
    MINOR = 1
    PATCH = 0
    
    # 環境変数からのバージョン取得（CI/CD環境での上書き用）
    def self.from_env
      ENV['APP_VERSION']
    end
    
    # Gitコミットハッシュの取得（開発環境用）
    def self.git_sha
      return ENV['GIT_SHA'] if ENV['GIT_SHA'].present?
      
      begin
        `git rev-parse --short HEAD`.chomp.presence
      rescue
        nil
      end
    end
    
    # バージョン文字列の生成
    def self.to_s
      [from_env, [MAJOR, MINOR, PATCH].join('.'), git_sha].compact.first
    end
  end
end

# アプリケーション設定にバージョン情報を追加
Rails.application.config.version = Eventa::Version.to_s 