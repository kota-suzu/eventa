############################################
# Eventa Makefile v2-fixed (2025-05-04)
# 読める・守れる・拡張できる を最優先！
############################################

### ====== 共通設定 ====== ###
SHELL          := /bin/bash -e -o pipefail
MAKEFLAGS      += --silent
.RECIPEPREFIX   = \	# ← レシピ先頭を “\t” に固定（可視化用）
.ONESHELL:          # 各ターゲットを 1 シェルで実行

COMPOSE     := docker compose
EXEC        := $(COMPOSE) exec
API_EXEC    = $(EXEC) api
FE_EXEC     = $(EXEC) frontend
DB_EXEC     = $(EXEC) db

DB_PASS     ?= rootpass
DATABASE    ?= $$MYSQL_DATABASE
RIDGEPOLE   = $(API_EXEC) bundle exec ridgepole -c config/database.yml -E development \
              DB_HOST=db DATABASE_PASSWORD=$(DB_PASS)

### ====== アウトプット用ヘルパ ====== ###
define banner
	$(info )
	$(info \033[1;36m== $(1) ==\033[0m)
endef

### ====== ショートカット ====== ###
define lint_backend
	$(call banner,"Backend Lint")
	$(API_EXEC) bundle exec standardrb
endef

define test_backend
	$(call banner,"Backend Test")
	$(API_EXEC) bundle exec rspec
endef

define lint_frontend
	$(call banner,"Frontend Lint")
	$(FE_EXEC) npm run lint
endef

define test_frontend
	$(call banner,"Frontend Test")
	$(FE_EXEC) npm test
endef

### ====== ターゲット宣言 ====== ###
PHONY_TARGETS := help dev down stop restart logs \
	backend-lint backend-test backend-coverage backend-db-export backend-db-apply backend-db-dry-run \
	frontend-dev frontend-logs frontend-lint frontend-test frontend-build \
	full-check full-report setup-check docker-clean env-example fix-auth auth-diagnosis fix-user-factory fix-auth-all

.PHONY: $(PHONY_TARGETS)
.DEFAULT_GOAL := help

### ====== ヘルプ ====== ###
help:  ## 💁 各種コマンド一覧
	@echo -e "\033[1;34m== Eventa Make v2 Commands ==\033[0m"
	@grep -E '^[a-zA-Z0-9:_-]+:.*##' $(MAKEFILE_LIST) \
		| sed -E 's/^([^:]+):.*##[[:space:]]*(.*)$$/"\1","\2"/' \
		| column -s, -t | sort

### ====== 基本操作 ====== ###
dev: ## 🚀 フルスタック (API+FE) 起動 & DB準備
	$(call banner,"Compose up")
	$(COMPOSE) up -d --build
	$(API_EXEC) bin/rails db:prepare

down: ## 🗑 コンテナ+ボリューム削除
	$(call banner,"Compose down -v")
	$(COMPOSE) down -v

stop: ## ⏹ サービス停止
	$(COMPOSE) stop

restart: ## 🔄 API 再起動
	$(COMPOSE) restart api

logs: ## 📜 api + frontend ログ tail
	$(COMPOSE) logs -f --tail=100 api frontend

docker-clean: ## 🧹 Docker 全体お掃除
	docker system prune -af --volumes

### ====== Backend 名前空間 ====== ###
backend-lint:  ## 🧹 Rails Lint
	$(lint_backend)

backend-test:  ## 🧪 Rails Test
	$(test_backend)

backend-coverage: ## 📊 SimpleCov レポート
	COVERAGE=on $(call test_backend)

backend-db-export: ## 📤 Schemafile エクスポート
	$(RIDGEPOLE) --export -o db/Schemafile

backend-db-apply: ## 📥 Schemafile 適用
	$(RIDGEPOLE) --apply -f db/Schemafile

backend-db-dry-run: ## 🔍 Schemafile ドライラン
	@echo "RIDGEPOLEコマンド: $(RIDGEPOLE) --apply --dry-run -f db/Schemafile"
	$(RIDGEPOLE) --apply --dry-run -f db/Schemafile || { \
		echo "\033[1;31mSchemafileに問題があります。上記エラーを確認してください\033[0m"; exit 1; }

### ====== Frontend 名前空間 ====== ###
frontend-dev: ## 🌐 FE 開発サーバ起動
	$(COMPOSE) up -d frontend

frontend-logs: ## 📋 FE ログ
	$(FE_EXEC) npm run logs || true

frontend-lint: ## 🧹 FE Lint
	$(lint_frontend)

frontend-test: ## 🧪 FE Test
	$(test_frontend)

frontend-build: ## 🔨 FE Production Build
	$(FE_EXEC) npm run build

### ====== フルチェック ====== ###
full-check: ## 🔍 API & FE 総合品質チェック
	@echo "\033[1;36m=== フルスタック品質検証開始 ===\033[0m"

	@echo "\n\033[1;34m>> Backend Lint 実行中...\033[0m"
	$(MAKE) backend-lint   || { echo "\033[1;31m✖ Backend Lintに失敗しました\033[0m"; exit 1; }
	@echo "\033[1;32m✓ Backend Lint OK\033[0m"

	@echo "\n\033[1;34m>> DB Schema 検証中...\033[0m"
	$(MAKE) backend-db-dry-run || { echo "\033[1;31m✖ DB Schema検証に失敗しました\033[0m"; exit 1; }
	@echo "\033[1;32m✓ DB Schema OK\033[0m"

	@echo "\n\033[1;34m>> Backend Tests 実行中...\033[0m"
	$(MAKE) backend-test   || { \
		echo "\033[1;31m✖ テスト失敗。Auth 関連なら 'make fix-auth' を試してください\033[0m"; exit 1; }
	@echo "\033[1;32m✓ Backend Tests OK\033[0m"

	@echo "\n\033[1;34m>> Frontend Lint 実行中...\033[0m"
	$(MAKE) frontend-lint  || { echo "\033[1;31m✖ Frontend Lintに失敗しました\033[0m"; exit 1; }
	@echo "\033[1;32m✓ Frontend Lint OK\033[0m"

	@echo "\n\033[1;34m>> Frontend Tests 実行中...\033[0m"
	$(MAKE) frontend-test  || { echo "\033[1;31m✖ Frontend Testsに失敗しました\033[0m"; exit 1; }
	@echo "\033[1;32m✓ Frontend Tests OK\033[0m"

	@echo "\n\033[1;34m>> Frontend Build 実行中...\033[0m"
	$(FE_EXEC) npm run build || { echo "\033[1;31m✖ Frontend Buildに失敗しました\033[0m"; exit 1; }
	@echo "\033[1;32m✓ Frontend Build OK\033[0m"

	@echo "\n\033[1;32m✓ 全ての検証が正常に完了しました！\033[0m"

full-report: ## 📝 full-check + レポート出力
	mkdir -p tmp/report
	-$(MAKE) backend-lint    > tmp/report/backend_lint.txt    2>&1
	-$(MAKE) backend-test    > tmp/report/backend_test.txt    2>&1
	-$(MAKE) frontend-lint   > tmp/report/frontend_lint.txt   2>&1
	-$(MAKE) frontend-test   > tmp/report/frontend_test.txt   2>&1
	-$(MAKE) frontend-build  > tmp/report/frontend_build.txt  2>&1
	@echo "reports in tmp/report"

### ====== セットアップ診断 ====== ###
setup-check: ## 🩺 Docker・依存パッケージの健全性チェック
	$(call banner,"Setup Check")
	$(COMPOSE) ps | grep -q "Up" && echo "✓ containers up" || { echo "✖ containers down"; exit 1; }
	$(API_EXEC) bundle check && echo "✓ gems ok"
	$(FE_EXEC)  npm list > /dev/null && echo "✓ npm ok"

env-example: ## 📑 .env.example を生成
	./scripts/env_diff.sh

### ====== 認証問題診断・修正 ====== ###
auth-diagnosis: ## 🔍 認証関連の問題を診断
	$(call banner,"Auth Diagnosis")
	# -- 以下略。タブ行を崩さず元の処理をそのまま残す --

fix-user-factory: ## 🛠️ ユーザーファクトリ修正
	$(call banner,"Fix User Factory")
	# -- 元の処理をタブありでそのまま配置 --

fix-auth: ## 🔧 認証関連の基本的な問題を修正
	$(call banner,"Auth Fix")
	# -- 元の処理をタブありでそのまま配置 --

fix-auth-all: ## 🔨 認証システム全体を包括的に修正
	$(call banner,"全面的な認証修正")
	# -- 元の処理をタブありでそのまま配置 --

############################################
# ここまで。ターゲット追加時は PHONY_TARGETS に追記！
############################################
