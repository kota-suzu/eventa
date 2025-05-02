.PHONY: dev reset-db help test lint lint-auto ci logs console shell restart migrate seed deploy seed-test docker-clean db-apply db-dry-run db-export stop frontend frontend-logs check-all check-all-report fix-all check-frontend setup-check full-stack-check frontend-fix frontend-health frontend-deps

# Ridgepoleコマンド共通部分
RIDGEPOLE_CMD = docker compose exec -e DB_HOST=db -e DATABASE_PASSWORD=$${DATABASE_PASSWORD:-rootpass} api bundle exec ridgepole -c config/database.yml -E development

help: ## 🔍 利用可能なコマンド一覧
	@echo "\033[1;34m== Eventa API 開発ツール ==\033[0m"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-16s\033[0m %s\n", $$1, $$2}' | column -t

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

check-all: ## 🔎 開発品質チェック一括実行 (lint + db検証 + test)
	@echo "\033[1;36m=== 開発品質総合チェック開始 ===\033[0m"
	
	@echo "\n\033[1;34m>> コード品質チェック (lint) 実行中...\033[0m"
	@make lint || (echo "\033[1;31mLintエラーが検出されました\033[0m"; exit 1)
	@echo "\033[1;32m✓ Lint成功\033[0m"
	
	@echo "\n\033[1;34m>> DBマイグレーション検証中...\033[0m"
	@make db-dry-run || (echo "\033[1;31mSchemafileに問題があります\033[0m"; exit 1)
	@echo "\033[1;32m✓ DBスキーマ検証成功\033[0m"
	
	@echo "\n\033[1;34m>> テスト実行中...\033[0m"
	@make test || (echo "\033[1;31mテストに失敗しました\033[0m"; exit 1)
	@echo "\033[1;32m✓ テスト成功\033[0m"
	
	@echo "\n\033[1;32m=== 全チェック完了：問題は検出されませんでした ===\033[0m"

check-all-report: ## 📝 全チェックを中断せず実行して総合レポート生成
	@echo "\033[1;36m=== 品質レポート生成開始 ===\033[0m"
	@mkdir -p tmp/reports
	
	@echo "\n\033[1;34m>> コード品質チェック実行中...\033[0m"
	@make lint > tmp/reports/lint_report.txt 2>&1; \
	LINT_STATUS=$$?; \
	if [ $$LINT_STATUS -eq 0 ]; then \
		echo "\033[1;32m✓ Lintチェック成功\033[0m"; \
	else \
		echo "\033[1;33m⚠ Lintエラーがあります（詳細はレポート参照）\033[0m"; \
	fi
	
	@echo "\n\033[1;34m>> DBマイグレーション検証中...\033[0m"
	@make db-dry-run > tmp/reports/db_report.txt 2>&1; \
	DB_STATUS=$$?; \
	if [ $$DB_STATUS -eq 0 ]; then \
		echo "\033[1;32m✓ DBスキーマ検証成功\033[0m"; \
	else \
		echo "\033[1;33m⚠ DBスキーマに問題があります（詳細はレポート参照）\033[0m"; \
	fi
	
	@echo "\n\033[1;34m>> テスト実行中...\033[0m"
	@make test > tmp/reports/test_report.txt 2>&1; \
	TEST_STATUS=$$?; \
	if [ $$TEST_STATUS -eq 0 ]; then \
		echo "\033[1;32m✓ テスト成功\033[0m"; \
	else \
		echo "\033[1;33m⚠ テスト失敗があります（詳細はレポート参照）\033[0m"; \
	fi
	
	@echo "\n\033[1;36m=== レポート作成完了 ===\033[0m"
	@echo "レポートファイル:"
	@echo "- Lint: tmp/reports/lint_report.txt"
	@echo "- DB検証: tmp/reports/db_report.txt"
	@echo "- テスト: tmp/reports/test_report.txt"
	@echo ""
	@echo "結果サマリー:"
	@LINT_STATUS=`grep -c "Run \`standardrb --fix\`" tmp/reports/lint_report.txt || echo 0`; \
	DB_STATUS=`grep -c "ERROR" tmp/reports/db_report.txt || echo 0`; \
	TEST_STATUS=`grep -c "examples, .* failures" tmp/reports/test_report.txt | awk '{print $$5}' || echo 0`; \
	echo "- Lint: $${LINT_STATUS} 件の修正推奨"; \
	echo "- DB検証: $${DB_STATUS} 件のエラー"; \
	echo "- テスト: $${TEST_STATUS} 件の失敗"; \
	TOTAL_ISSUES=$$((LINT_STATUS + DB_STATUS + TEST_STATUS)); \
	if [ $$TOTAL_ISSUES -eq 0 ]; then \
		echo "\n\033[1;32m✓ 全チェック完了：問題はありません\033[0m"; \
	else \
		echo "\n\033[1;33m⚠ $${TOTAL_ISSUES} 件の問題があります\033[0m"; \
	fi

fix-all: ## 🔧 自動修正可能な問題を一括修正
	@echo "\033[1;36m=== 自動コード修正開始 ===\033[0m"
	
	@echo "\n\033[1;34m>> Lint自動修正実行中...\033[0m"
	@make lint-auto || echo "\033[1;33m⚠ 一部の問題は手動修正が必要です\033[0m"
	
	@echo "\n\033[1;34m>> DBスキーマ差異の確認中...\033[0m"
	@if [ ! -s db/Schemafile ]; then \
		echo "\033[1;33m⚠ Schemafileが空か存在しません。エクスポート実行...\033[0m"; \
		make db-export || echo "\033[1;31m✖ DBスキーマのエクスポートに失敗しました\033[0m"; \
	else \
		echo "\033[1;32m✓ Schemafileは既に存在します\033[0m"; \
	fi
	
	@echo "\n\033[1;32m=== 自動修正完了 ===\033[0m"

check-frontend: ## 🌐 フロントエンド品質チェック
	@echo "\033[1;36m=== フロントエンド品質チェック開始 ===\033[0m"
	
	@echo "\n\033[1;34m>> Node.js依存関係チェック...\033[0m"
	@if [ -f frontend/package-lock.json ]; then \
		docker compose exec frontend npm audit || echo "\033[1;33m⚠ 依存関係に脆弱性があります\033[0m"; \
		echo "\033[1;32m✓ 依存関係チェック完了\033[0m"; \
	else \
		echo "\033[1;33m⚠ package-lock.jsonが見つかりません\033[0m"; \
	fi
	
	@echo "\n\033[1;34m>> フロントエンドLintチェック...\033[0m"
	@if [ -f frontend/package.json ]; then \
		if grep -q "\"lint\":" frontend/package.json; then \
			docker compose exec frontend npm run lint || echo "\033[1;33m⚠ Lintエラーがあります\033[0m"; \
			echo "\033[1;32m✓ Lintチェック完了\033[0m"; \
		else \
			echo "\033[1;33m⚠ Lintスクリプトが定義されていません\033[0m"; \
		fi \
	else \
		echo "\033[1;33m⚠ package.jsonが見つかりません\033[0m"; \
	fi
	
	@echo "\n\033[1;34m>> フロントエンドビルドテスト...\033[0m"
	@if [ -f frontend/package.json ]; then \
		if grep -q "\"build\":" frontend/package.json; then \
			docker compose exec frontend npm run build || echo "\033[1;33m⚠ ビルドエラーがあります\033[0m"; \
			echo "\033[1;32m✓ ビルドテスト完了\033[0m"; \
		else \
			echo "\033[1;33m⚠ ビルドスクリプトが定義されていません\033[0m"; \
		fi \
	else \
		echo "\033[1;33m⚠ package.jsonが見つかりません\033[0m"; \
	fi
	
	@echo "\n\033[1;32m=== フロントエンド品質チェック完了 ===\033[0m"

setup-check: ## 🔧 開発環境のセットアップ状態確認
	@echo "\033[1;36m=== 開発環境セットアップ確認 ===\033[0m"
	
	@echo "\n\033[1;34m>> Dockerコンテナ起動状態確認...\033[0m"
	@docker compose ps --format json | grep -q "\"State\":\"running\"" && \
		echo "\033[1;32m✓ Dockerコンテナは起動しています\033[0m" || \
		echo "\033[1;31m✖ 一部のコンテナが停止しています。'make dev'を実行してください\033[0m"
	
	@echo "\n\033[1;34m>> DBアクセス確認...\033[0m"
	@docker compose exec db mysqladmin -uroot -p$${DATABASE_PASSWORD:-rootpass} ping --silent > /dev/null 2>&1 && \
		echo "\033[1;32m✓ DBアクセス可能です\033[0m" || \
		echo "\033[1;31m✖ DBアクセスできません。認証情報を確認してください\033[0m"
	
	@echo "\n\033[1;34m>> API依存関係確認...\033[0m"
	@docker compose exec api bundle check > /dev/null 2>&1 && \
		echo "\033[1;32m✓ Gemはインストール済みです\033[0m" || \
		echo "\033[1;31m✖ 不足しているGemがあります。'docker compose exec api bundle install'を実行してください\033[0m"
	
	@echo "\n\033[1;34m>> フロントエンド依存関係確認...\033[0m"
	@docker compose exec frontend npm list > /dev/null 2>&1 && \
		echo "\033[1;32m✓ NPM依存関係はインストール済みです\033[0m" || \
		echo "\033[1;31m✖ フロントエンド依存関係に問題があります。'docker compose exec frontend npm install'を実行してください\033[0m"
	
	@echo "\n\033[1;32m=== セットアップ確認完了 ===\033[0m"

full-stack-check: ## 🔎 フロントエンド・バックエンド総合品質チェック
	@echo "\033[1;36m=== フルスタック品質検証開始 ===\033[0m"
	@echo "\n\033[1;34m>> バックエンド品質チェック開始 <<\033[0m"
	@echo "\n\033[1;34m>> コード品質チェック実行中...\033[0m"
	@LINT_ISSUES=0; \
	LINT_OUTPUT=$$(make lint 2>&1 || echo "ERROR"); \
	LINT_STATUS=$$?; \
	echo "$$LINT_OUTPUT"; \
	if [ $$LINT_STATUS -eq 0 ]; then \
		echo "\033[1;32m✓ Lintチェック成功\033[0m"; \
	else \
		echo "\033[1;33m⚠ Lintエラーがあります\033[0m"; \
		LINT_ISSUES=$$(echo "$$LINT_OUTPUT" | grep -c "Run \`standardrb --fix\`" || echo 0); \
		if [ $$LINT_ISSUES -eq 0 ]; then LINT_ISSUES=1; fi; \
	fi; \
	echo "LINT_ISSUES=$$LINT_ISSUES" > /tmp/full-stack-check-report.env
	
	@echo "\n\033[1;34m>> DBマイグレーション検証中...\033[0m"
	@DB_ISSUES=0; \
	DB_OUTPUT=$$(make db-dry-run 2>&1 || echo "ERROR"); \
	DB_STATUS=$$?; \
	echo "$$DB_OUTPUT"; \
	if [ $$DB_STATUS -eq 0 ]; then \
		echo "\033[1;32m✓ DBスキーマ検証成功\033[0m"; \
	else \
		echo "\033[1;33m⚠ DBスキーマに問題があります\033[0m"; \
		DB_ISSUES=$$(echo "$$DB_OUTPUT" | grep -c "ERROR" || echo 0); \
		if [ $$DB_ISSUES -eq 0 ]; then DB_ISSUES=1; fi; \
	fi; \
	echo "DB_ISSUES=$$DB_ISSUES" >> /tmp/full-stack-check-report.env
	
	@echo "\n\033[1;34m>> バックエンドテスト実行中...\033[0m"
	@TEST_FAILURES=0; \
	TEST_OUTPUT=$$(make test 2>&1 || echo "ERROR"); \
	TEST_STATUS=$$?; \
	echo "$$TEST_OUTPUT"; \
	if [ $$TEST_STATUS -eq 0 ]; then \
		echo "\033[1;32m✓ テスト成功\033[0m"; \
	else \
		echo "\033[1;33m⚠ テスト失敗があります\033[0m"; \
		TEST_FAILURES=$$(echo "$$TEST_OUTPUT" | grep -c "examples, .* failures" | xargs echo || echo 0); \
		if [ "$$TEST_FAILURES" = "" ] || [ $$TEST_FAILURES -eq 0 ]; then \
			TEST_FAILURES=$$(echo "$$TEST_OUTPUT" | grep -c "error\|Error\|failed\|Failed" || echo 0); \
			if [ $$TEST_FAILURES -eq 0 ]; then TEST_FAILURES=1; fi; \
		fi; \
	fi; \
	echo "TEST_FAILURES=$$TEST_FAILURES" >> /tmp/full-stack-check-report.env
	
	@echo "\n\033[1;34m>> フロントエンド品質チェック開始 <<\033[0m"
	
	@echo "\n\033[1;34m>> フロントエンドLintチェック...\033[0m"
	@FRONTEND_LINT_ISSUES=0; \
	if [ -f frontend/package.json ]; then \
		if grep -q "\"lint\":" frontend/package.json; then \
			FRONTEND_LINT_OUTPUT=$$(docker compose exec frontend npm run lint 2>&1 || echo "ERROR"); \
			FRONTEND_LINT_STATUS=$$?; \
			echo "$$FRONTEND_LINT_OUTPUT"; \
			if [ $$FRONTEND_LINT_STATUS -eq 0 ]; then \
				echo "\033[1;32m✓ フロントエンドLintチェック成功\033[0m"; \
			else \
				echo "\033[1;33m⚠ フロントエンドLintエラーがあります\033[0m"; \
				FRONTEND_LINT_ISSUES=$$(echo "$$FRONTEND_LINT_OUTPUT" | grep -c "error\|warning\|Would you like to configure" || echo 0); \
				if [ $$FRONTEND_LINT_ISSUES -eq 0 ]; then FRONTEND_LINT_ISSUES=1; fi; \
			fi; \
		else \
			echo "\033[1;33m⚠ Lintスクリプトが定義されていません\033[0m"; \
			FRONTEND_LINT_ISSUES=0; \
		fi; \
	else \
		echo "\033[1;33m⚠ package.jsonが見つかりません\033[0m"; \
		FRONTEND_LINT_ISSUES=0; \
	fi; \
	echo "FRONTEND_LINT_ISSUES=$$FRONTEND_LINT_ISSUES" >> /tmp/full-stack-check-report.env
	
	@echo "\n\033[1;34m>> フロントエンドテスト実行中...\033[0m"
	@FRONTEND_TEST_FAILURES=0; \
	if [ -f frontend/package.json ]; then \
		if grep -q "\"test\":" frontend/package.json; then \
			FRONTEND_TEST_OUTPUT=$$(docker compose exec frontend npm test 2>&1 || echo "ERROR"); \
			FRONTEND_TEST_STATUS=$$?; \
			echo "$$FRONTEND_TEST_OUTPUT"; \
			if [ $$FRONTEND_TEST_STATUS -eq 0 ]; then \
				echo "\033[1;32m✓ フロントエンドテスト成功\033[0m"; \
			else \
				echo "\033[1;33m⚠ フロントエンドテスト失敗があります\033[0m"; \
				FRONTEND_TEST_FAILURES=$$(echo "$$FRONTEND_TEST_OUTPUT" | grep -c "failing\|failed" || echo 0); \
				if [ $$FRONTEND_TEST_FAILURES -eq 0 ]; then FRONTEND_TEST_FAILURES=1; fi; \
			fi; \
		else \
			echo "\033[1;33m⚠ テストスクリプトが定義されていません\033[0m"; \
			echo "frontend/package.jsonに\"test\"スクリプトを追加することを検討してください"; \
			FRONTEND_TEST_FAILURES=0; \
		fi; \
	else \
		echo "\033[1;33m⚠ package.jsonが見つかりません\033[0m"; \
		FRONTEND_TEST_FAILURES=0; \
	fi; \
	echo "FRONTEND_TEST_FAILURES=$$FRONTEND_TEST_FAILURES" >> /tmp/full-stack-check-report.env
	
	@echo "\n\033[1;34m>> フロントエンドビルドチェック...\033[0m"
	@FRONTEND_BUILD_ISSUES=0; \
	if [ -f frontend/package.json ]; then \
		if grep -q "\"build\":" frontend/package.json; then \
			FRONTEND_BUILD_OUTPUT=$$(docker compose exec frontend npm run build 2>&1 || echo "ERROR"); \
			FRONTEND_BUILD_STATUS=$$?; \
			echo "$$FRONTEND_BUILD_OUTPUT"; \
			if [ $$FRONTEND_BUILD_STATUS -eq 0 ]; then \
				echo "\033[1;32m✓ フロントエンドビルド成功\033[0m"; \
			else \
				echo "\033[1;33m⚠ フロントエンドビルドエラーがあります\033[0m"; \
				FRONTEND_BUILD_ISSUES=$$(echo "$$FRONTEND_BUILD_OUTPUT" | grep -c "error\|ERROR\|Failed to compile" || echo 0); \
				if [ $$FRONTEND_BUILD_ISSUES -eq 0 ]; then FRONTEND_BUILD_ISSUES=1; fi; \
			fi; \
		else \
			echo "\033[1;33m⚠ ビルドスクリプトが定義されていません\033[0m"; \
			FRONTEND_BUILD_ISSUES=0; \
		fi; \
	else \
		echo "\033[1;33m⚠ package.jsonが見つかりません\033[0m"; \
		FRONTEND_BUILD_ISSUES=0; \
	fi; \
	echo "FRONTEND_BUILD_ISSUES=$$FRONTEND_BUILD_ISSUES" >> /tmp/full-stack-check-report.env
	
	@echo "\n\033[1;36m=== 総合レポート ===\033[0m"
	@source /tmp/full-stack-check-report.env; \
	echo "結果サマリー:"; \
	echo "- バックエンドLint: $${LINT_ISSUES} 件の修正推奨"; \
	echo "- DB検証: $${DB_ISSUES} 件のエラー"; \
	echo "- バックエンドテスト: $${TEST_FAILURES} 件の失敗"; \
	echo "- フロントエンドLint: $${FRONTEND_LINT_ISSUES} 件の問題"; \
	echo "- フロントエンドテスト: $${FRONTEND_TEST_FAILURES} 件の失敗"; \
	echo "- フロントエンドビルド: $${FRONTEND_BUILD_ISSUES} 件の問題"; \
	TOTAL_ISSUES=$$((LINT_ISSUES + DB_ISSUES + TEST_FAILURES + FRONTEND_LINT_ISSUES + FRONTEND_TEST_FAILURES + FRONTEND_BUILD_ISSUES)); \
	echo "- 合計: $${TOTAL_ISSUES} 件の問題"; \
	if [ $$TOTAL_ISSUES -eq 0 ]; then \
		echo "\n\033[1;32m✓ フルスタック検証完了：問題はありません\033[0m"; \
	else \
		echo "\n\033[1;33m⚠ 合計 $${TOTAL_ISSUES} 件の問題があります\033[0m"; \
	fi; \
	rm -f /tmp/full-stack-check-report.env

frontend-deps: ## 📦 フロントエンド依存関係の再インストール
	@echo "\033[1;36m=== フロントエンド依存関係の再インストール ===\033[0m"
	@docker compose exec frontend npm install
	@echo "\033[1;32m✓ 依存関係のインストール完了\033[0m"

frontend-fix: ## 🔧 フロントエンド環境の自動修復
	@echo "\033[1;36m=== フロントエンド環境修復 ===\033[0m"
	
	@echo "\n\033[1;34m>> 依存関係の再インストール中...\033[0m"
	@make frontend-deps
	
	@echo "\n\033[1;34m>> フロントエンドコンテナ再起動中...\033[0m"
	@docker compose restart frontend
	@echo "\033[1;32m✓ フロントエンドコンテナを再起動しました\033[0m"
	
	@echo "\n\033[1;32m=== フロントエンド環境修復完了 ===\033[0m"
	@echo "ブラウザで http://localhost:3000 にアクセスして動作確認してください"

frontend-health: ## 🩺 フロントエンド環境の健全性チェック
	@echo "\033[1;36m=== フロントエンド健全性診断 ===\033[0m"
	
	@echo "\n\033[1;34m>> コンテナ起動状態確認...\033[0m"
	@docker compose ps frontend --format json | grep -q "\"State\":\"running\"" && \
		echo "\033[1;32m✓ フロントエンドコンテナは起動しています\033[0m" || \
		echo "\033[1;31m✖ フロントエンドコンテナが停止しています。'make frontend'を実行してください\033[0m"
	
	@echo "\n\033[1;34m>> 開発サーバーアクセス確認...\033[0m"
	@curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 | grep -q "200" && \
		echo "\033[1;32m✓ 開発サーバーにアクセス可能です\033[0m" || \
		echo "\033[1;31m✖ 開発サーバーにアクセスできません。'make frontend-fix'を実行してください\033[0m"
	
	@echo "\n\033[1;34m>> 主要JSリソース確認...\033[0m"
	@curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/_next/static/chunks/main.js 2>/dev/null | grep -q "200" && \
		echo "\033[1;32m✓ メインJSリソースが正常に配信されています\033[0m" || \
		echo "\033[1;31m✖ メインJSリソースにアクセスできません。'make frontend-fix'を実行してください\033[0m"
	
	@echo "\n\033[1;34m>> 設定ファイル確認...\033[0m"
	@if [ -f frontend/next.config.js ]; then \
		echo "\033[1;32m✓ Next.js設定ファイルが存在します\033[0m"; \
	else \
		echo "\033[1;31m✖ Next.js設定ファイルが見つかりません\033[0m"; \
	fi
	
	@echo "\n\033[1;34m>> 環境変数確認...\033[0m"
	@if [ -f frontend/.env.local ]; then \
		if grep -q "NEXT_PUBLIC_API_URL" frontend/.env.local; then \
			echo "\033[1;32m✓ API URL設定が存在します\033[0m"; \
		else \
			echo "\033[1;33m⚠ API URLが設定されていません\033[0m"; \
		fi \
	else \
		echo "\033[1;33m⚠ .env.localファイルが見つかりません\033[0m"; \
	fi
	
	@echo "\n\033[1;32m=== 診断完了 ===\033[0m"
	@echo "問題が見つかった場合は 'make frontend-fix' を実行してください"

.DEFAULT_GOAL := help