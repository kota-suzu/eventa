#!/bin/bash
set -e

# データベースが利用可能になるまで待機
function wait_for_db() {
  echo "データベース接続を確認中..."
  max_attempts=30
  attempt=0
  
  while [ $attempt -lt $max_attempts ]; do
    attempt=$((attempt+1))
    
    echo "接続確認 試行 $attempt/$max_attempts"
    if mysql -h$DATABASE_HOST -u$DATABASE_USERNAME -p$DATABASE_PASSWORD -e "SELECT 1;" > /dev/null 2>&1; then
      echo "データベース接続が確立されました！"
      return 0
    fi
    
    echo "データベースに接続できません。5秒後に再試行します..."
    sleep 5
  done
  
  echo "データベースへの接続が確立できませんでした。アプリケーションを終了します。"
  return 1
}

# マイグレーションとシードの実行
function setup_database() {
  echo "データベースのセットアップを開始します..."
  
  if [[ "$RAILS_ENV" == "development" || "$RAILS_ENV" == "test" ]]; then
    echo "開発/テスト環境のデータベースをセットアップしています..."
    bundle exec rake db:setup 2>/dev/null || bundle exec rake db:migrate
  else
    echo "本番環境のデータベースをマイグレーションしています..."
    bundle exec rake db:migrate
  fi
  
  echo "データベースのセットアップが完了しました！"
}

# Railsキャッシュのクリア
function clear_rails_cache() {
  echo "Railsキャッシュをクリアしています..."
  bundle exec rake tmp:clear
  echo "キャッシュのクリアが完了しました！"
}

# メイン処理
echo "アプリケーションの起動準備を開始します..."

if [[ -z $DATABASE_HOST || -z $DATABASE_USERNAME || -z $DATABASE_PASSWORD ]]; then
  echo "警告: データベース接続情報が設定されていません。接続チェックをスキップします。"
else
  wait_for_db || exit 1
  setup_database
fi

clear_rails_cache

# 渡されたコマンドを実行
echo "アプリケーションを起動します: $@"
exec "$@" 