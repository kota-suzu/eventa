############################################
# Eventa Makefile v2-parallel-fixed + coverage (2025-05-05)
############################################

###############################
# Environment for test target #
###############################
# テスト環境用の安全な固定キー
export RAILS_ENV = test
export RAILS_MASTER_KEY = 0123456789abcdef0123456789abcdef
export SECRET_KEY_BASE = test_secret_key_base_for_safe_testing_only
export RAILS_ENCRYPTION_PRIMARY_KEY = 00000000000000000000000000000000
export RAILS_ENCRYPTION_DETERMINISTIC_KEY = 11111111111111111111111111111111
export RAILS_ENCRYPTION_KEY_DERIVATION_SALT = 2222222222222222222222222222222222222222222222222222222222222222
export JWT_SECRET_KEY = test_jwt_secret_key_for_tests_only
# Git警告対応 (docker内でのgit操作警告を抑制)
export GIT_DISCOVERY_ACROSS_FILESYSTEM = 1

# TODO: docker-compose.yml の `version` 属性の削除
# 警告が出ているので、docker compose 互換性のため将来的に削除する

# TODO: コンテナ内のgitリポジトリ対応
# `fatal: not a git repository`警告を解消するには、
# .gitをボリュームマウントするか、GIT_DISCOVERY_ACROSS_FILESYSTEM=1を設定する

# TODO: CI環境用の変数渡し整理
# 将来的にはすべての環境変数をdocker-compose.ymlに集約して、
# 個別のMakeターゲットでは指定しないようにする考慮も必要

### ===== 共通設定 ===== ###
SHELL          := /bin/bash -e -o pipefail
JOBS           ?= $(shell nproc)            # 並列度 (上書き可)
MAKEFLAGS      += --silent -j$(JOBS) -k     # -k: エラーでも続行
.RECIPEPREFIX  = \	                        # 可視タブ
.ONESHELL:

COMPOSE  := docker compose
DB_PASS  ?= rootpass
RIDGEPOLE_ENV ?= development
RIDGEPOLE = $(COMPOSE) exec -e DB_HOST=db -e DATABASE_PASSWORD=$(DB_PASS) -e RAILS_ENV=$(RIDGEPOLE_ENV) api bundle exec ridgepole -c config/database.yml -E $(RIDGEPOLE_ENV)

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
	$(COMPOSE) exec -e COVERAGE=true -e RAILS_ENV=test -e RAILS_MASTER_KEY=$(MASTER_KEY) api bundle exec rails tmp:clear
	$(COMPOSE) exec -e COVERAGE=true -e RAILS_ENV=test -e RAILS_MASTER_KEY=$(MASTER_KEY) api bundle exec rspec

backend-db-dry-run: ## 🔍 Ridgepole DryRun
	$(banner) "Schema DryRun"
	$(COMPOSE) exec -e RAILS_ENV=test -e RAILS_MASTER_KEY=$(MASTER_KEY) api bundle exec ridgepole -c config/database.yml -E test --apply --dry-run -f db/Schemafile --no-color

backend-test-api-force: ## 🧪 APIテストを強制的に実行
	$(banner) "API Tests (Force Run)"
	$(COMPOSE) exec -e RAILS_ENV=test -e FORCE_API_TESTS=true -e RAILS_MASTER_KEY=$(MASTER_KEY) api bundle exec rspec spec/requests/

.NOTPARALLEL: backend-fix-api
backend-fix-api: ## 🔧 API通過テスト修正＋実行
	$(banner) "API Test Fix"
	-$(COMPOSE) exec -e RAILS_MASTER_KEY=$(MASTER_KEY) api bundle exec standardrb --fix-unsafely spec/support/pending_api_helper.rb
	$(COMPOSE) exec -e RAILS_ENV=test -e FORCE_API_TESTS=true -e RAILS_MASTER_KEY=$(MASTER_KEY) api bundle exec rspec spec/requests/

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
full-check: ## 🔍 全体チェック（Lint + Test）
	@echo "Running full-check with $(RAILS_ENV)"
	$(banner) "全体チェック実行"
	@$(MAKE) db-test-health || \
	(echo "\033[1;33m⚠️ テストデータベースの健全性チェックに失敗しました。修復してリトライします...\033[0m" && \
	$(MAKE) db-test-repair && $(MAKE) db-test-health)
	@$(MAKE) backend-lint
	@$(MAKE) frontend-lint
	@$(MAKE) backend-test
	@$(MAKE) frontend-test
	@echo "\033[1;32m✓ 全体チェック完了\033[0m"

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
	$(COMPOSE) exec api bundle config set --local without ""
	$(COMPOSE) exec api bundle config set --local deployment "false"
	# デフォルトgemとの競合を避けるための設定
	$(COMPOSE) exec api bash -c 'cd /app && if grep -q "error_highlight" Gemfile; then sed -i -e "/error_highlight/s/^/if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new(\x22\3.3.0\x22\)\n  /" -e "/error_highlight/s/$/\nend/" Gemfile; fi'
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

diagnose-db: ## 🔍 データベーススキーマ診断
	$(banner) "データベーススキーマ診断"
	@echo "開発環境スキーマ適用状況:"
	-$(RIDGEPOLE) --apply --dry-run -f db/Schemafile | grep -v "Table Options" || true
	@echo "\nテスト環境スキーマ適用状況:"
	-$(COMPOSE) exec -e RAILS_ENV=test api bundle exec ridgepole -c config/database.yml -E test --apply --dry-run -f db/Schemafile | grep -v "Table Options" || true
	@echo "\nテスト環境テーブル一覧:"
	-$(COMPOSE) exec -e RAILS_ENV=test api bundle exec rails runner 'puts ActiveRecord::Base.connection.tables.sort'
	@echo "\nデータベースアダプタの確認:"
	-$(COMPOSE) exec -e RAILS_ENV=test api bundle exec rails runner 'puts "テスト環境DB: #{ActiveRecord::Base.connection.adapter_name}"'
	@echo "\033[1;32m✓ データベース診断完了\033[0m"

check-ci-db: ## 🔍 CI環境用データベース設定確認
	$(banner) "CI環境データベース設定確認"
	@echo "現在の設定:"
	-$(COMPOSE) exec api bundle exec rails runner 'config = Rails.configuration.database_configuration["test"]; puts "Adapter: #{config["adapter"] || "未設定"}"; puts "Host: #{config["host"] || "未設定"}"; puts "Database: #{config["database"] || "未設定"}"'
	@echo "\nMySQL接続テスト:"
	-$(COMPOSE) exec -e RAILS_ENV=test api bundle exec rails runner 'begin; puts "接続成功: #{ActiveRecord::Base.connection.execute("SELECT 1").to_a.inspect}"; rescue => e; puts "接続エラー: #{e.message}"; end'
	@echo "\033[1;32m✓ CI環境データベース確認完了\033[0m"

repair-test-db: ## 🚨 テストデータベースを緊急修復
	$(banner) "テストDB緊急修復"
	@echo "テストデータベースを緊急修復しています..."
	@$(COMPOSE) exec -e RAILS_ENV=test api bundle exec rails ridgepole:repair_test
	@echo "\033[1;32m✓ テストデータベースの修復が完了しました\033[0m"

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
	$(COMPOSE) exec api bundle exec flog -a app/**/*.rb | grep -v -E "#none|flog/method|flog total" | awk '{if ($$1>20) {print $$0}}' || true
	@echo "\n改善が必要な上位5メソッド:"
	$(COMPOSE) exec api bundle exec flog -a app/**/*.rb | grep -v -E "#none|flog/method|flog total" | sort -nr | head -5
	@echo "\nCIチェック:"
	-$(COMPOSE) exec api bash -c 'cd /app && bundle exec flog -a app/**/*.rb | grep -v -E "#none|flog/method|flog total" | awk "{if (\$$1 > 20) {print; exit 1}}" || echo "✅ 全てのメソッドが複雑度閾値内(20以下)です！"'

backend-code-smells: ## 🧐 コードスメル検出
	$(banner) "コードスメル検出"
	$(COMPOSE) exec api bundle exec reek app

backend-quality: backend-coverage backend-complexity backend-code-smells ## 🔬 すべての品質チェック
	$(banner) "コード品質分析完了"
	@echo "\033[1;32m✓ コード品質レポートの生成が完了しました\033[0m"

### ===== ブランチカバレッジ向上ターゲット ===== ###
test-payment-service: ## 💳 PaymentServiceのテスト実行
	$(banner) "PaymentServiceのテスト実行"
	$(COMPOSE) exec -e COVERAGE=true -e RAILS_ENV=test -e RAILS_MASTER_KEY=$(MASTER_KEY) api bundle exec rspec spec/services/payment_service_spec.rb

test-auths: ## 🔑 認証関連テスト実行
	$(banner) "認証関連のテスト実行"
	$(COMPOSE) exec -e COVERAGE=true -e RAILS_ENV=test -e RAILS_MASTER_KEY=$(MASTER_KEY) api bundle exec rspec spec/requests/auths_spec.rb

test-event: ## 🎟 Eventモデルのテスト実行
	$(banner) "Eventモデルのテスト実行"
	$(COMPOSE) exec -e COVERAGE=true -e RAILS_ENV=test -e RAILS_MASTER_KEY=$(MASTER_KEY) api bundle exec rspec spec/models/event_spec.rb

high-coverage: test-payment-service test-auths test-event ## 🏆 ブランチカバレッジ向上テスト一括実行
	$(banner) "ブランチカバレッジ向上テスト実行完了"
	$(MAKE) coverage-summary
	@echo "\033[1;32m✓ ブランチカバレッジ向上テスト完了\033[0m"

############################################
# 追加ターゲットは help の自動抽出だけで OK
############################################


### ===== CI互換チェック & Git インサイト ===== ###

# ./github/workflows/** と同じコマンド列を 1Shot で
local-ci: ## 🏃‍♂️ GitHub Actions と同内容のローカル CI
	$(banner) "Local CI (GitHub Actions ミラー) 開始"
	CI=true $(MAKE) full-check
	@echo "\033[1;32m✓ Local CI 完了\033[0m"

# CI環境をシミュレートして実行するターゲット
ci-simulate: ## 🤖 CI環境をシミュレートして特定のテストを実行
	$(banner) "CI環境シミュレーション"
	$(banner) "データベースリセット＆準備"
	$(COMPOSE) exec -e RAILS_ENV=test -e RAILS_MASTER_KEY=$(MASTER_KEY) api bundle exec rails db:prepare
	$(banner) "テーブル確認"
	$(COMPOSE) exec -e RAILS_ENV=test -e RAILS_MASTER_KEY=$(MASTER_KEY) api bundle exec rails runner 'tables = ActiveRecord::Base.connection.tables.sort; puts "テーブル一覧 (#{tables.size}件): #{tables.join(", ")}"; puts "データベースアダプタ: #{ActiveRecord::Base.connection.adapter_name}"'
	$(banner) "認証テスト実行"
	$(COMPOSE) exec -e RAILS_ENV=test -e COVERAGE=true -e RAILS_MASTER_KEY=$(MASTER_KEY) api bundle exec rspec spec/services/json_web_token_spec.rb spec/models/user_spec.rb spec/requests/auths_spec.rb
	@echo "\033[1;32m✓ CI環境シミュレーション完了\033[0m"

# CI用の診断機能（CIパイプラインチェック用）
ci-healthcheck: ## 👩‍⚕️ CIパイプラインの健全性チェック
	$(banner) "CIパイプライン健全性チェック"
	$(banner) "データベース接続確認"
	$(COMPOSE) exec -e RAILS_ENV=test -e RAILS_MASTER_KEY=$(MASTER_KEY) api bundle exec rails runner 'begin; tables = ActiveRecord::Base.connection.tables.sort; puts "テーブル確認OK (#{tables.size}件): #{tables.join(", ")}"; rescue => e; puts "DB接続エラー: #{e.message}"; exit 1; end'
	$(banner) "重要なテーブルの存在確認"
	$(COMPOSE) exec -e RAILS_ENV=test -e RAILS_MASTER_KEY=$(MASTER_KEY) api bundle exec rails runner 'critical_tables = %w[events users tickets ticket_types participants reservations]; missing = critical_tables - ActiveRecord::Base.connection.tables; if missing.empty?; puts "✅ 重要テーブルは全て存在します"; else; puts "❌ 不足テーブル: #{missing.join(", ")}"; exit 1; end'
	$(banner) "usersテーブル構造確認"
	$(COMPOSE) exec -e RAILS_ENV=test -e RAILS_MASTER_KEY=$(MASTER_KEY) api bundle exec rails runner 'begin; columns = ActiveRecord::Base.connection.columns("users"); if columns.any?; puts "✅ usersテーブルのカラム数: #{columns.size}"; else; puts "❌ usersテーブルにカラムがありません"; exit 1; end; rescue => e; puts "❌ usersテーブル確認エラー: #{e.message}"; exit 1; end'
	@echo "\033[1;32m✓ CIパイプライン健全性チェック完了\033[0m"

# Git 履歴から修正回数が多い "アツい" ファイル上位 20 % を抽出
hot-files: ## 🔥 修正回数上位 20% のファイル一覧
	$(banner) "Hot Files (Top 20%)"
	@total=$$(git log --pretty=format: --name-only | grep -v '^$$' | sort -u | wc -l); \
	 top_n=$$(( (total + 4)/5 )); \
	 git log --pretty=format: --name-only | grep -v '^$$' | \
	 sort | uniq -c | sort -nr | head -n $$top_n

# pre-push フックを自動生成（ローカル CI を強制）
install-pre-push: ## 🛡 push 前に make local-ci を自動実行する Git Hook をセット
	$(banner) "pre-push Hook をインストール"
	@mkdir -p .git/hooks
	@echo '#!/usr/bin/env bash\nset -e\nmake local-ci' > .git/hooks/pre-push
	@chmod +x .git/hooks/pre-push
	@echo '\033[1;32m✓ pre-push フックを設定しました。push 時に Local CI が走ります。\033[0m'

### ===== データベース診断と修復コマンド ===== ###
db-test-health: ## 🏥 テストDB健全性チェック
	@echo "テストデータベースの健全性チェックを実行しています..."
	@$(COMPOSE) exec -e RAILS_ENV=test -e RAILS_MASTER_KEY=$(MASTER_KEY) api \
	    bundle exec rake test:db_health || \
	 (echo "テストDBに問題 → 修復を試みます..." && $(MAKE) db-test-repair)

db-test-repair: ## 🔧 テストDB修復（緊急用）
	@echo "テストデータベースの修復を実行しています..."
	@$(COMPOSE) exec -e RAILS_ENV=test -e RAILS_MASTER_KEY=$(MASTER_KEY) api \
	    bundle exec rake test:db_repair

db-test-reset: ## 🧹 テスト環境データベース接続リセット
	$(banner) "テストDB接続リセット"
	@echo "テストデータベース接続をリセットしています..."
	@$(COMPOSE) exec -e RAILS_ENV=test -e RAILS_MASTER_KEY=$(MASTER_KEY) api bundle exec rails db:test:prepare || \
		(echo "標準リセット失敗。緊急修復を実行します..." && \
		$(COMPOSE) exec -e RAILS_ENV=test -e RAILS_MASTER_KEY=$(MASTER_KEY) api bundle exec rails ridgepole:repair_test)
	@echo "FactoryBotの設定をリロードしています..."
	@$(COMPOSE) exec -e RAILS_ENV=test -e RAILS_MASTER_KEY=$(MASTER_KEY) api bundle exec rails runner 'FactoryBot.reload if defined?(FactoryBot)'
	@echo "✓ テストデータベース接続のリセットが完了しました"

backend-test-reconnect: ## 🔄 バックエンドテスト（接続リセット付き）
	$(banner) "接続リセット付きバックエンドテスト"
	# まず接続をリセットしてからテストを実行
	$(COMPOSE) exec -e RAILS_ENV=test -e RAILS_MASTER_KEY=$(MASTER_KEY) api bundle exec rails db:health:reset
	$(COMPOSE) exec -e COVERAGE=true -e RAILS_ENV=test -e RAILS_MASTER_KEY=$(MASTER_KEY) api bundle exec rails tmp:clear
	$(COMPOSE) exec -e COVERAGE=true -e RAILS_ENV=test -e RAILS_MASTER_KEY=$(MASTER_KEY) api bundle exec rspec

# CI互換テストを実行（テスト環境の健全性確認付き）
ci-test: ## 🧪 CI互換のUserモデルとAuth関連のテストを実行

# テストのデバッグ実行（詳細な出力）
debug-test:
	@echo "詳細モードでテストを実行しています..."
	@$(COMPOSE) exec -e RAILS_ENV=test -e VERBOSE=true -e RAILS_MASTER_KEY=$(MASTER_KEY) api bundle exec rspec --format documentation

# データベース診断コマンド
db-diagnostic:
	@echo "データベース診断を実行しています..."
	@$(COMPOSE) exec -e RAILS_MASTER_KEY=$(MASTER_KEY) api bundle exec rails runner 'puts "データベース情報:"; puts "- 環境: #{Rails.env}"; puts "- データベース: #{ActiveRecord::Base.connection.current_database}"; puts "- テーブル数: #{ActiveRecord::Base.connection.tables.size}"; puts "テーブル一覧:"; ActiveRecord::Base.connection.tables.each { |t| puts "- #{t}" }'

# テストデータベース専用の診断
test-db-diagnostic:
	@echo "テストデータベース診断を実行しています..."
	@$(COMPOSE) exec -e RAILS_ENV=test -e RAILS_MASTER_KEY=$(MASTER_KEY) api bundle exec rails runner 'puts "テストデータベース情報:"; puts "- データベース: #{ActiveRecord::Base.connection.current_database}"; puts "- テーブル数: #{ActiveRecord::Base.connection.tables.size}"; tables = ActiveRecord::Base.connection.tables; if tables.empty?; puts "警告: テーブルが存在しません！"; else; puts "テーブル一覧:"; tables.each { |t| puts "- #{t}" }; end'

# テスト環境のスキーマDRYラン
test-schema-dry-run: ## 🔍 テスト環境のスキーマDRYラン
	$(banner) "テスト環境スキーマDRYラン"
	@echo "テスト環境のスキーマをチェックしています..."
	@$(COMPOSE) exec -e RAILS_ENV=test -e RAILS_MASTER_KEY=$(MASTER_KEY) api bundle exec rails ridgepole:dry_run

### ===== JWT認証テスト ===== ###
jwt-test-setup: ## 🔑 JWT認証テスト環境のセットアップ
	$(banner) "JWT認証テスト環境をセットアップ"
	$(COMPOSE) exec -e RAILS_ENV=test -e RAILS_MASTER_KEY=0123456789abcdef0123456789abcdef api bundle exec rake jwt:test:setup

jwt-test: jwt-test-setup ## 🔑 JWT認証関連のテスト実行
	$(banner) "JWT認証テスト"
	$(COMPOSE) exec -e RAILS_ENV=test -e RAILS_MASTER_KEY=0123456789abcdef0123456789abcdef api bundle exec rake jwt:test:run

jwt-test-service: jwt-test-setup ## 🔑 TokenBlacklistServiceのテスト実行
	$(banner) "TokenBlacklistServiceテスト"
	$(COMPOSE) exec -e RAILS_ENV=test -e RAILS_MASTER_KEY=0123456789abcdef0123456789abcdef api bundle exec rspec spec/services/token_blacklist_service_spec.rb --format documentation

jwt-test-auth: jwt-test-setup ## 🔑 認証コントローラのテスト実行 
	$(banner) "認証コントローラテスト"
	$(COMPOSE) exec -e RAILS_ENV=test -e RAILS_MASTER_KEY=0123456789abcdef0123456789abcdef api bundle exec rspec spec/controllers/api/v1/auths_controller_spec.rb --format documentation

############################################
# 追加ターゲットは help の自動抽出だけで OK
############################################
