# Eventa プロジェクト実装TODOリスト

このファイルはEventaプロジェクトで実装が必要な項目をまとめたTODOリストです。各機能は優先度に応じて実装を進めてください。

## 優先度の高い実装項目（!urgent）

- JWT認証アルゴリズムをHS256からRS256へ変更（`api/app/services/json_web_token.rb`）
- パスワード強度のバリデーション強化（`api/app/models/user.rb`）
- レート制限の実装（ブルートフォース攻撃防止）（`api/app/controllers/api/v1/auths_controller.rb`）
- チケット管理機能の完全実装（`api/app/models/ticket_type.rb`）
- 支払い処理システムの完全実装（`api/app/services/payment_service.rb`）
- イベント詳細ページの拡張（`frontend/pages/events/[id].js`）
- グローバルエラーハンドリングの強化（`api/app/controllers/application_controller.rb`）
- API仕様書の完成と更新（`docs/TODO.md`）

## セキュリティ関連（!security）

- トークンリボケーション（失効）の仕組みを追加（`api/app/services/json_web_token.rb`）
- JWT有効期限管理の強化（`api/app/services/json_web_token.rb`）
- ログアウト時のトークン無効化機能（`api/app/controllers/api/v1/auths_controller.rb`）
- セッション管理テーブルへの保存（`api/app/controllers/api/v1/auths_controller.rb`）
- アカウントロック機能の実装（`api/app/models/user.rb`）
- IPアドレスベースの追加検証（`api/app/controllers/application_controller.rb`）
- 決済セキュリティ強化（`api/app/services/payment_service.rb`）
- チケット詐欺防止機能（`api/app/models/ticket_type.rb`）

## 機能拡張（!feature）

- トークン更新（リフレッシュ）フローの最適化（`api/app/services/json_web_token.rb`）
- デバイス情報を含めた多要素認証対応（`api/app/services/json_web_token.rb`）
- ソーシャルログイン機能の実装（`api/app/controllers/api/v1/auths_controller.rb`）
- パスワードリセットフローの強化（`api/app/controllers/api/v1/auths_controller.rb`）
- 二要素認証(2FA)の実装（`api/app/models/user.rb`）
- プロフィール管理機能の拡張（`api/app/models/user.rb`）
- イベントのタグ機能を追加（`api/app/models/event.rb`）
- イベント検索・フィルタリング機能の強化（`api/app/models/event.rb`）
- イベント共有機能の実装（`api/app/models/event.rb`）
- 繰り返しイベントの対応（`api/app/models/event.rb`）
- チケット予約システムの最適化（`api/app/models/ticket_type.rb`）
- チケット状態の自動更新処理（`api/app/models/ticket_type.rb`）
- 複数通貨のサポート（`api/app/models/ticket_type.rb`）
- 決済履歴管理機能（`api/app/services/payment_service.rb`）
- 返金処理システム（`api/app/services/payment_service.rb`）
- 複数決済方法のサポート（`api/app/services/payment_service.rb`）
- APIレート制限の実装（`api/app/controllers/application_controller.rb`）
- E2Eテストの追加（`api/spec/controllers/application_controller_spec.rb`）
- ストレステストの実装（`api/spec/controllers/application_controller_spec.rb`）
- サーバーレスアーキテクチャの検討（`api/config/environments/production.rb`）
- アクセシビリティ対応（`frontend/pages/dashboard.js`）

## フロントエンド関連（!frontend）

- イベント詳細ページの拡張（`frontend/pages/events/[id].js`）
- チケット購入フローの実装（`frontend/pages/events/[id].js`）
- ソーシャル共有機能の追加（`frontend/pages/events/[id].js`）
- ユーザーダッシュボードの機能強化（`frontend/pages/dashboard.js`）
- APIからユーザー関連イベントを取得（`frontend/pages/dashboard.js`）
- レスポンシブデザインの最適化（`frontend/pages/dashboard.js`）
- ユーザー設定管理機能（`frontend/pages/dashboard.js`）

## パフォーマンス関連（!performance）

- キャパシティに関する計算をキャッシュする（`api/app/models/event.rb`）
- レスポンスキャッシュの最適化（`api/app/controllers/application_controller.rb`）
- イベントデータのローカルキャッシュ（`frontend/pages/events/[id].js`）
- キャッシュ戦略の実装（`api/app/services/cache_service.rb`）
- N+1クエリ問題の解消（`api/app/services/cache_service.rb`）
- データベースインデックス最適化（`api/app/services/cache_service.rb`）
- バッチ処理の最適化（`api/app/services/cache_service.rb`）
- 水平スケーリング対応（`api/config/environments/production.rb`）
- CDN統合とアセット最適化（`api/config/environments/production.rb`）

## ドキュメンテーション関連（!documentation）

- API仕様書の完成と更新（`docs/TODO.md`）
- エラーコード体系の整備（`docs/TODO.md`）
- API使用ガイドラインの追加（`docs/TODO.md`）
- 変更履歴の管理（`docs/TODO.md`）
- セットアップガイドの改善（`docs/TODO.md`）
- 操作マニュアルの作成（`docs/TODO.md`）
- アーキテクチャドキュメントの更新（`docs/TODO.md`）
- テストカバレッジを高める（`api/spec/controllers/application_controller_spec.rb`）

## 実装時の注意事項

1. 優先度の高い項目（!urgent）から着手してください
2. セキュリティ関連の項目（!security）は早期に対応してください
3. 各機能は対応するテストコードも併せて実装してください
4. TODOコメントは実装完了後に削除し、コミットメッセージに対応するTODO項目を記載してください
5. 実装に関する疑問点があれば、チームメンバーに相談するか、関連ドキュメントを参照してください

## テストデータベース関連

- [ ] CIパイプラインの安定化（特にテストデータベース）
  - [x] テストデータベース初期化の改善
  - [x] Ridgepoleを使ったスキーマ適用の安定化
  - [ ] テストデータベース接続問題の自動診断と修復
  - [ ] CI環境での並列テスト最適化
- [ ] フロントエンドのテスト拡充
- [ ] APIエンドポイントの認証強化
- [ ] イベント予約システムの機能拡張

## データベース関連

- [x] テストデータベース修復コマンドの追加と改善
- [x] Ridgepoleタスクの拡張（テスト環境適用）
- [x] FactoryBot初期化の安定化
- [ ] データベース接続エラーの自動リトライシステム最適化
- [ ] テストデータベースのパフォーマンス改善
- [ ] MySQLバージョン8.0と5.7の互換性対応
- [ ] マイグレーションAPI変更（Rails 8対応）の最終確認

## テスト安定性向上

- [x] テストヘルパーの改善（接続リトライ機能）
- [x] DatabaseCleaner設定の強化
- [ ] 不安定（フレーキー）テストの検出と改善
- [ ] テストパフォーマンスメトリクスの収集と分析
- [ ] テスト並列実行の安定性向上
- [ ] RSpec設定の最適化（テスト分類、フィルタリング）

## Rails 8対応

- [x] マイグレーションAPI変更への対応
- [x] autoload_libの設定追加
- [ ] ActiveRecord接続管理の変更対応
- [ ] 非推奨機能の置き換え
- [ ] Rails 8特有の機能活用検討

## ドキュメント・ナレッジ

- [ ] テストデータベース設定ガイドの作成
- [ ] 開発環境セットアップ手順の更新
- [ ] トラブルシューティングガイドの拡充
- [ ] CI/CD設定の詳細ドキュメント化

## セキュリティ強化

- [ ] 依存パッケージの脆弱性スキャン自動化
- [ ] セキュリティヘッダーの設定見直し
- [ ] 入力検証の強化
- [ ] 認証・認可フローのセキュリティレビュー

## 残り課題（今回対応で見つかった課題）

- [ ] データベース接続問題の追跡システムと自動レポート - docs/guides/test_stability.md作成予定
- [ ] CI環境でのテストデータベース設定最適化 - テストパフォーマンス向上のため
- [ ] テストスイート実行時間の短縮 - 部分的スキーマロード導入を検討
- [ ] Rails 9互換性の事前確認 - Rails.gem_version.segments.firstを使った分岐を検討
- [ ] 不要になったbootstrapコードの廃止 - Rails標準のdb:prepareに統合検討
- [ ] スキーマ検証の最適化（パフォーマンス向上）
- [ ] 並列テスト環境でのスキーマ適用方法の改善
- [ ] Ridgepoleエラーメッセージの改善とログ集約
- [ ] CI環境での自動スキーマ修復と通知メカニズム 