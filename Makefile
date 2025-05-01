.PHONY: dev reset-db help test lint ci logs console shell restart migrate seed deploy seed-test docker-clean db-apply db-dry-run db-export

help: ## 🔍 利用可能なコマンド一覧
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-12s\033[0m %s\n", $$1, $$2}'

dev: ## ▶️ フルスタック起動
	docker compose up -d --build
	docker compose exec api bin/rails db:prepare

reset-db: ## 💣 DB 初期化
	docker compose down -v && docker compose up -d db

lint: ## 🧹 コード品質チェック
	docker compose exec api bundle exec standardrb

test: ## 🧪 テスト実行
	docker compose exec api bundle exec rspec

ci: lint test ## 🚀 CI パイプライン実行 (lint + test)

logs: ## 📋 アプリケーションのログを表示
	docker compose logs -f api

console: ## 🖥 Rails コンソールを起動
	docker compose exec api bin/rails console

shell: ## 🐚 APIコンテナにシェルアクセス
	docker compose exec api bash

restart: ## 🔄 アプリケーションを再起動
	docker compose restart api

migrate: ## 📊 データベースマイグレーション実行
	docker compose exec api bin/rails db:migrate

rollback: ## ⏪ マイグレーションを1つ戻す
	docker compose exec api bin/rails db:rollback

seed: ## 🌱 シードデータを投入
	docker compose exec api bin/rails db:seed

seed-test: ## 🧪 テスト用シードデータを投入
	docker compose exec api bin/rails db:seed RAILS_ENV=test

routes: ## 🛣 ルーティング一覧を表示
	docker compose exec api bin/rails routes

docker-clean: ## 🧹 未使用のDocker資産を削除
	docker system prune -f

stop: ## ⏹ コンテナを停止
	docker compose stop

docs: ## 📚 APIドキュメントを生成
	docker compose exec api bin/rails rswag:specs:swaggerize

# Ridgepole関連のコマンド
db-apply: ## 📊 Schemafileの変更をDBに適用
	docker compose exec -e DB_HOST=db -e DATABASE_PASSWORD=rootpass api bundle exec ridgepole -c config/database.yml -E development --apply -f db/Schemafile.rb

db-dry-run: ## 🔍 Schemafileの変更をシミュレーション
	docker compose exec -e DB_HOST=db -e DATABASE_PASSWORD=rootpass api bundle exec ridgepole -c config/database.yml -E development --apply --dry-run -f db/Schemafile.rb

db-export: ## 📤 現在のDBスキーマをSchemafileにエクスポート
	docker compose exec -e DB_HOST=db -e DATABASE_PASSWORD=rootpass api bundle exec ridgepole -c config/database.yml -E development --export -o db/Schemafile.rb

.DEFAULT_GOAL := help