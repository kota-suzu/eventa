### ===== JWT認証テスト ===== ###
jwt-test-setup: ## 🔑 JWT認証テスト環境のセットアップ
	$(banner) "JWT認証テスト環境をセットアップ"
	$(COMPOSE) exec -e RAILS_ENV=test api bin/jwt_ci -r

jwt-test: jwt-test-setup ## 🔑 JWT認証関連のテスト実行
	$(banner) "JWT認証テスト"
	$(COMPOSE) exec -e RAILS_ENV=test api bin/jwt_ci -a

jwt-test-service: jwt-test-setup ## 🔑 TokenBlacklistServiceのテスト実行
	$(banner) "TokenBlacklistServiceテスト"
	$(COMPOSE) exec -e RAILS_ENV=test api bin/jwt_ci -s

jwt-test-auth: jwt-test-setup ## 🔑 認証コントローラのテスト実行 
	$(banner) "認証コントローラテスト"
	$(COMPOSE) exec -e RAILS_ENV=test api bin/jwt_ci -c 

# テスト環境関連の追加設定
full-check: ## 🔍 全体チェック（Lint + Test）
	$(banner) "全体チェック実行"
	@$(MAKE) db-test-health || \
	(echo "\033[1;33m⚠️ テストデータベースの健全性チェックに失敗しました。修復してリトライします...\033[0m" && \
	$(MAKE) db-test-repair && $(MAKE) db-test-health)
	@$(MAKE) db-test-load-env
	@$(MAKE) backend-lint
	@$(MAKE) frontend-lint
	@$(MAKE) backend-test
	@$(MAKE) frontend-test
	@echo "\033[1;32m✓ 全体チェック完了\033[0m"

# テスト環境の環境変数読み込み
db-test-load-env: ## 📥 テスト環境の環境変数を読み込み
	$(banner) "テスト環境変数ロード"
	@if [ -f api/.env.test ]; then \
		echo "テスト環境変数をロードします"; \
		export $$(cat api/.env.test | grep -v '^#' | xargs) && \
		echo "✓ テスト環境変数をロードしました"; \
	else \
		echo "⚠️ api/.env.testファイルが見つかりません"; \
	fi

# Gitリポジトリ警告の抑制
git-check: ## 🔍 Git状態確認（警告抑制付き）
	@git rev-parse --is-inside-work-tree >/dev/null 2>&1 || echo "⚠️ Gitリポジトリ外です - 警告は無視されます" 