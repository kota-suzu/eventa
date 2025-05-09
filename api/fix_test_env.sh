#!/bin/bash
# Rails 8のテスト環境を修復するためのユーティリティスクリプト

set -e  # エラー時に停止

echo "===== Rails 8テスト環境修復スクリプト ====="

# 環境変数設定
export RAILS_ENV=test
export RAILS_MASTER_KEY=0123456789abcdef0123456789abcdef  # テスト用16バイトキー
export SECRET_KEY_BASE=0123456789abcdef0123456789abcdef0123456789abcdef  # テスト用

# 現在のディレクトリ確認
if [ ! -f "./config/application.rb" ]; then
  echo "Railsアプリケーションのルートディレクトリで実行してください"
  exit 1
fi

# テスト用master.keyファイル作成
if [ ! -f "./config/master.key" ]; then
  echo "テスト用のmaster.keyを作成します"
  echo "0123456789abcdef0123456789abcdef" > ./config/master.key
  chmod 600 ./config/master.key
fi

# データベース修復
echo "テストデータベースを修復します..."
bundle exec rake ridgepole:repair_test || bundle exec rake db:test:emergency_repair

# データベース接続リセット
echo "データベース接続をリセットします..."
bundle exec rake db:health:reset

# JWT認証テスト環境の準備
echo "JWT認証テスト環境を設定します..."
bundle exec rake jwt:test:setup

echo "✅ テスト環境修復完了"
echo "以下のコマンドでテストを実行できます:"
echo "bundle exec rspec spec/services/token_blacklist_service_spec.rb" 