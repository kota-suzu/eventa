.PHONY: dev reset-db help test lint lint-auto ci logs console shell restart migrate seed deploy seed-test docker-clean db-apply db-dry-run db-export stop frontend frontend-logs

# Ridgepoleコマンド共通部分
RIDGEPOLE_CMD = docker compose exec -e DB_HOST=db -e DATABASE_PASSWORD=$${DATABASE_PASSWORD:-rootpass} api bundle exec ridgepole -c config/database.yml -E development

help: ## 🔍 利用可能なコマンド一覧
	@echo "\033[1;34m== Eventa API 開発ツール ==\033[0m"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-12s\033[0m %s\n", $$1, $$2}' | column -t

dev: ## ▶️ フルスタック起動
	docker compose up -d --build
	docker compose exec api bin/rails db:prepare

frontend: ## 🌐 フロントエンド開発サーバー起動
	docker compose up -d frontend

frontend-logs: ## 📋 フロントエンドのログを表示
	docker compose logs -f frontend

reset-db: ## 💣 DB 初期化
	docker compose down -v && docker compose up -d db

lint: ## 🧹 コード品質チェック
	docker compose exec api bundle exec standardrb

lint-auto: ## 🧹 コード品質チェック (自動修正)
	docker compose exec api bundle exec standardrb --fix

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
	$(RIDGEPOLE_CMD) --apply -f db/Schemafile

db-dry-run: ## 🔍 Schemafileの変更をシミュレーション
	$(RIDGEPOLE_CMD) --apply --dry-run -f db/Schemafile
	@echo "\n警告: 空のSchemafileは全テーブル削除の危険があります。先にdb-exportを実行してください。"
	@docker compose exec api bash -c 'grep -q . db/Schemafile || (echo "\033[31mエラー: Schemafileが空です！\033[0m"; exit 1)'

db-export: ## 📤 現在のDBスキーマをSchemafileにエクスポート
	$(RIDGEPOLE_CMD) --export -o db/Schemafile

.DEFAULT_GOAL := help