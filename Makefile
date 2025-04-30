.PHONY: dev reset-db help test lint ci

help: ## 🔍 利用可能なコマンド一覧
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-10s\033[0m %s\n", $$1, $$2}'

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

.DEFAULT_GOAL := help