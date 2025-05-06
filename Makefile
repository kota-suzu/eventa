############################################
# Eventa Makefile v2-parallel-fixed + coverage (2025-05-05)
############################################

### ===== 共通設定 ===== ###
SHELL          := /bin/bash -e -o pipefail
JOBS           ?= $(shell nproc)            # 並列度 (上書き可)
MAKEFLAGS      += --silent -j$(JOBS) -k     # -k: エラーでも続行
.RECIPEPREFIX  = \	                        # 可視タブ
.ONESHELL:

COMPOSE  := docker compose
DB_PASS  ?= rootpass
RIDGEPOLE = $(COMPOSE) exec -e DB_HOST=db -e DATABASE_PASSWORD=$(DB_PASS) api bundle exec ridgepole -c config/database.yml -E development

### ===== 出力ヘルパ ===== ###
banner = @echo; echo "\033[1;36m== $(1) ==\033[0m"

### ===== ターゲット自動抽出 ===== ###
# "##" 付きターゲットを PHONY に（必要であれば有効化してください）
# PHONY_TARGETS := $(shell awk -F: '/^[A-Za-z0-9_-]+:.*##/ {print $$1}' "$(MAKEFILE_LIST)")
# .PHONY: $(PHONY_TARGETS)
# .DEFAULT_GOAL := help

### ===== ヘルプ ===== ###
help: ## 💁 コマンド一覧
	@echo -e "\033[1;34m== Eventa Make Commands ==\033[0m"
	@awk -F: '/^[-[:alnum:]_]+:.*##/ {printf "%-25s %s\n", $$1, substr($$0,index($$0,"##")+3)}' $(MAKEFILE_LIST) | sort

### ===== ヘルプメッセージ関数 ===== ###
define SETUP_HELP
	@echo "\033[1;33m初めての実行時は以下のコマンドを実行してください：\033[0m"
	@echo "  make setup      # 依存関係のインストールとDB設定"
	@echo
	@echo "\033[1;33m開発環境の起動：\033[0m"
	@echo "  make dev        # 環境を起動してDBを準備"
	@echo
	@echo "\033[1;33mエラーが出た場合：\033[0m"
	@echo "  make down       # 環境をクリーンアップ"
	@echo "  make setup      # 再セットアップ"
endef

### ===== 基本操作 ===== ###
dev: ## 🚀 up + db:prepare
	$(banner) "Compose up"
	docker compose up -d --build
	$(banner) "Gemの更新とインストール"
	-$(COMPOSE) exec api bundle update
	-$(COMPOSE) exec api bundle install
	$(banner) "データベース準備"
	-$(COMPOSE) exec -e RAILS_ENV=development api bin/rails db:prepare || { \
		echo "\033[1;31m⚠️ エラーが発生しました\033[0m"; \
		$(SETUP_HELP); \
		exit 1; \
	}
	@echo "\033[1;32m✓ 開発環境セットアップ完了\033[0m"

down:        ## 🗑 コンテナ + ボリューム削除
	docker compose down -v

stop:        ## ⏹ 停止
	docker compose stop

restart:     ## 🔄 API 再起動
	docker compose restart api

logs:        ## 📜 ログ tail
	docker compose logs -f --tail=100 api frontend

docker-clean: ## 🧹 Docker GC
	docker system prune -af --volumes

### ===== Backend ===== ###
backend-fix:  ## 🔧 AutoFix
	$(banner) "Backend AutoFix"
	-$(COMPOSE) exec api bundle exec standardrb --fix-unsafely

backend-lint: ## 🧹 Lint
	$(banner) "Backend Lint"
	$(COMPOSE) exec api bundle exec standardrb

backend-test: ## 🧪 Test＋カバレッジ
	$(banner) "Backend Test"
	# Rails 8.0 互換性問題を回避するため tmp をクリア
	$(COMPOSE) exec -e COVERAGE=true -e RAILS_ENV=test api bundle exec rails tmp:clear
	$(COMPOSE) exec -e COVERAGE=true -e RAILS_ENV=test api bundle exec rspec

backend-db-dry-run: ## 🔍 Ridgepole DryRun
	$(banner) "Schema DryRun"
	$(RIDGEPOLE) --apply --dry-run -f db/Schemafile --no-color

.NOTPARALLEL: backend-ci
backend-ci: backend-fix backend-lint backend-db-dry-run backend-test ## 🔄 Backend 一括

### ===== Frontend ===== ###
frontend-fix:  ## 🔧 AutoFix
	$(banner) "Frontend AutoFix"
	-$(COMPOSE) exec frontend npm install --save-dev eslint eslint-config-next eslint-plugin-import eslint-plugin-react eslint-plugin-react-hooks eslint-plugin-jsx-a11y --silent --no-fund || true
	-$(COMPOSE) exec frontend npm run lint:fix --silent || true
	-$(COMPOSE) exec frontend npx prettier . --write --log-level error --no-color || true

frontend-lint: ## 🧹 Lint
	$(banner) "Frontend Lint"
	$(COMPOSE) exec frontend npm run lint --silent -- --no-cache

frontend-test: ## 🧪 Test
	$(banner) "Frontend Test"
	-$(COMPOSE) exec frontend npm test -- --ci || true

frontend-build: ## 🔨 Build
	$(banner) "Frontend Build"
	-$(COMPOSE) exec frontend npm run build --no-progress || true

.NOTPARALLEL: frontend-ci
frontend-ci: frontend-fix frontend-lint frontend-test frontend-build ## 🔄 Frontend 一括

### ===== フルチェック (並列) ===== ###
coverage-summary: ## 🔍 直近テストのカバレッジ要約
	$(banner) "Coverage summary"
	-$(COMPOSE) exec api sh -c 'test -f coverage/.resultset.json && jq -r '"'"'.[].result | "Line: \(.line)%, Branch: \(.branch)%"'"'"' coverage/.resultset.json | head -n1' || echo "No coverage results found"

.NOTPARALLEL: full-check
full-check: ## 🔍 Back & Front 同時検証
	$(banner) "フルチェック実行"
	$(MAKE) backend-ci || { \
		echo "\033[1;31m⚠️ バックエンドチェックでエラーが発生しました\033[0m"; \
		echo "エラーを修正するか、依存関係の問題の場合は 'make setup' を実行してください"; \
		exit 1; \
	}
	$(MAKE) frontend-ci || { \
		echo "\033[1;31m⚠️ フロントエンドチェックでエラーが発生しました\033[0m"; \
		echo "エラーを修正するか、依存関係の問題の場合は 'make setup' を実行してください"; \
		exit 1; \
	}
	$(banner) "カバレッジ要約"
	-$(MAKE) coverage-summary || true
	@echo "\033[1;32m✓ full-check 完了 (JOBS=$(JOBS))\033[0m"

### ===== レポート ===== ###
full-report: ## 📝 full-check + ログ保存
	rm -rf tmp/report && mkdir -p tmp/report
	-$(MAKE) backend-ci  > tmp/report/backend.txt  2>&1
	-$(MAKE) frontend-ci > tmp/report/frontend.txt 2>&1
	@echo "reports -> tmp/report"

### ===== セットアップ診断 ===== ###
setup-check: ## 🩺 コンテナ & 依存確認
	$(banner) "Setup Check"
	docker compose ps | grep -q "Up" && echo "✓ containers up" || echo "✖ containers down"
	$(COMPOSE) exec api bundle check
	$(COMPOSE) exec frontend npm ls --depth=0 > /dev/null

env-example: ## 📑 .env.example 生成
	./scripts/env_diff.sh

### ===== 一括 AutoFix ===== ###
fix-all: ## 🛠️ Backend + Frontend AutoFix
	-$(MAKE) backend-fix
	-$(MAKE) frontend-fix
	@echo "\033[1;32m✓ fix-all 完了\033[0m"

### ===== セットアップ ===== ###
setup: ## 🔧 依存関係インストール + DB準備
	$(banner) "初期セットアップを実行します"
	$(banner) "コンテナ起動"
	docker compose up -d --build
	$(banner) "バックエンドの依存関係インストール"
	$(COMPOSE) exec api bundle config set --local without ''
	$(COMPOSE) exec api bundle config set --local deployment 'false'
	$(COMPOSE) exec api bundle update && $(COMPOSE) exec api bundle install
	$(banner) "Stripe gemの確認とインストール"
	$(COMPOSE) exec api bundle show stripe || $(COMPOSE) exec api bundle add stripe
	$(banner) "フロントエンドの依存関係インストール"
	$(COMPOSE) exec frontend npm install
	$(banner) "データベース準備"
	$(COMPOSE) exec -e RAILS_ENV=development api bin/rails db:prepare
	$(COMPOSE) exec -e RAILS_ENV=test api bin/rails db:prepare
	@echo "\033[1;32m✓ 初期セットアップ完了\033[0m"
	$(SETUP_HELP)

### ===== デバッグと修復ツール ===== ###
diagnose: ## 🩺 環境診断
	$(banner) "環境診断を実行しています"
	@echo "コンテナ状態:"
	@docker compose ps
	@echo
	@echo "APIコンテナ診断:"
	-$(COMPOSE) exec api bundle check || echo "Bundlerに問題があります"
	-$(COMPOSE) exec api bundle exec rails -v || echo "Railsに問題があります"
	@echo
	@echo "フロントエンド診断:"
	-$(COMPOSE) exec frontend node -v || echo "Node.jsに問題があります"
	-$(COMPOSE) exec frontend npm -v || echo "NPMに問題があります"
	@echo
	@echo "依存関係の問題がある場合は 'make setup' を実行してください"

repair: ## 🔧 依存関係の修復
	$(banner) "依存関係の修復を実行しています"
	$(banner) "バックエンド修復"
	-$(COMPOSE) exec api bundle install
	$(banner) "フロントエンド修復"
	-$(COMPOSE) exec frontend npm install
	@echo "\033[1;32m✓ 修復が完了しました\033[0m"
	$(SETUP_HELP)

test-setup: ## 🧪 セットアップのテスト
	$(banner) "セットアップ後の動作確認"
	$(COMPOSE) exec api bundle show stripe
	$(COMPOSE) exec api bundle exec rails runner 'puts "DB接続OK: #{ActiveRecord::Base.connection.active?}"'
	$(COMPOSE) exec frontend npm ls --depth=0 eslint
	@echo "\033[1;32m✓ セットアップ正常確認完了\033[0m"

sidekiq-test: ## 🕒 Sidekiqジョブとスケジューラのテスト
	$(banner) "Sidekiq Job Test"
	$(COMPOSE) exec api bundle exec rails runner 'puts "Sidekiq: #{Sidekiq::VERSION}"; puts "Schedule Loaded: #{Sidekiq.schedule.inspect}"'
	$(COMPOSE) exec api bundle exec rspec spec/jobs/update_ticket_type_status_job_spec.rb spec/services/ticket_type_status_update_service_spec.rb

### ===== コード品質 ===== ###
code-stats: ## 📊 コード品質スコアカード
	$(banner) "コード品質スコア生成"
	$(COMPOSE) exec api bundle exec rubycritic --no-browser

backend-coverage: ## 📈 コードカバレッジ HTML
	$(banner) "カバレッジレポート生成"
	$(COMPOSE) exec -e COVERAGE=true -e RAILS_ENV=test api bundle exec rspec
	@echo "\nカバレッジレポートは ./api/coverage/index.html を開いてください。"

backend-complexity: ## 🧮 コード複雑度分析
	$(banner) "メソッド複雑度分析"
	$(COMPOSE) exec api bundle exec flog -d app/**/*.rb | grep -B 1 "flog total" || true
	@echo "\n複雑度が20を超えるメソッドのリスト:"
	$(COMPOSE) exec api bundle exec flog -ag app/**/*.rb | awk '$$1>20 {print $$0}' || true
	@echo "\n改善が必要な上位5メソッド:"
	$(COMPOSE) exec api bundle exec flog -ag app/**/*.rb | head -n 20 | grep -v "flog" | grep -v "^$$" | sort -nr | head -5

backend-code-smells: ## 🧐 コードスメル検出
	$(banner) "コードスメル検出"
	$(COMPOSE) exec api bundle exec reek app

backend-quality: backend-coverage backend-complexity backend-code-smells ## 🔬 すべての品質チェック
	$(banner) "コード品質分析完了"
	@echo "\033[1;32m✓ コード品質レポートの生成が完了しました\033[0m"

### ===== ブランチカバレッジ向上ターゲット ===== ###
test-payment-service: ## 💳 PaymentServiceのテスト実行
	$(banner) "PaymentServiceのテスト実行"
	$(COMPOSE) exec -e COVERAGE=true -e RAILS_ENV=test api bundle exec rspec spec/services/payment_service_spec.rb

test-auths: ## 🔑 認証関連テスト実行
	$(banner) "認証関連のテスト実行"
	$(COMPOSE) exec -e COVERAGE=true -e RAILS_ENV=test api bundle exec rspec spec/requests/auths_spec.rb

test-event: ## 🎟 Eventモデルのテスト実行
	$(banner) "Eventモデルのテスト実行"
	$(COMPOSE) exec -e COVERAGE=true -e RAILS_ENV=test api bundle exec rspec spec/models/event_spec.rb

high-coverage: test-payment-service test-auths test-event ## 🏆 ブランチカバレッジ向上テスト一括実行
	$(banner) "ブランチカバレッジ向上テスト実行完了"
	$(MAKE) coverage-summary
	@echo "\033[1;32m✓ ブランチカバレッジ向上テスト完了\033[0m"

############################################
# 追加ターゲットは help の自動抽出だけで OK
############################################
