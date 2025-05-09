#!/bin/bash
# JWT認証テスト実行スクリプト

set -e  # エラー時に停止

echo "===== JWT認証テスト実行スクリプト ====="

# 環境変数設定
export RAILS_ENV=test
export RAILS_MASTER_KEY=0123456789abcdef0123456789abcdef  # テスト用16バイトキー

# 現在のディレクトリ確認
if [ ! -f "./config/application.rb" ]; then
  echo "Railsアプリケーションのルートディレクトリで実行してください"
  exit 1
fi

# JWT認証テスト環境の準備
echo "JWT認証テスト環境を設定しています..."
bundle exec rake jwt:test:setup

# テスト実行
echo "JWT関連のテストを実行しています..."

if [ "$1" = "help" ]; then
  echo "使用法:"
  echo "./run_jwt_tests.sh                  - すべてのJWT関連テストを実行"
  echo "./run_jwt_tests.sh service          - TokenBlacklistServiceのテストを実行"
  echo "./run_jwt_tests.sh controller       - 認証コントローラのテストを実行"
  echo "./run_jwt_tests.sh jwt              - JsonWebTokenクラスのテストを実行"
  echo "./run_jwt_tests.sh rake             - Rakeタスクによるテストを実行"
  exit 0
fi

case "$1" in
  "service")
    echo "TokenBlacklistServiceのテストを実行しています..."
    bundle exec rspec spec/services/token_blacklist_service_spec.rb --format documentation
    ;;
  "controller")
    echo "認証コントローラのテストを実行しています..."
    bundle exec rspec spec/controllers/api/v1/auths_controller_spec.rb --format documentation
    ;;
  "jwt")
    echo "JsonWebTokenクラスのテストを実行しています..."
    bundle exec rspec spec/services/json_web_token_spec.rb --format documentation
    ;;
  "rake")
    echo "Rakeタスクによるテストを実行しています..."
    bundle exec rake jwt:test:run
    ;;
  *)
    echo "すべてのJWT関連テストを実行しています..."
    bundle exec rspec spec/services/token_blacklist_service_spec.rb spec/services/json_web_token_spec.rb --format documentation
    ;;
esac

echo "✅ テスト実行完了" 