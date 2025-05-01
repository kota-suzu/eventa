# eventa 運用 Runbook (v0.1)

**更新日**: 2025-04-30  
**作成者**: SREチーム  
**対象環境**: Production (prod), Staging (stg)

## 目的
本 Runbook は eventa のサービスレベル (SLO: P95 レイテンシ < 300 ms, エラー率 < 0.1 %) を維持しつつ、インシデントを速やかに検知・緩和・復旧するための標準手順を提供する。

## 参照情報

| 区分 | 詳細 |
|-----|------|
| 監視ダッシュボード | Grafana: prod/eventa-overview |
| ログ | Loki: service=eventa / Sentry: project=eventa-fe |
| Runbook 改訂履歴 | GitHub: docs/runbook/CHANGELOG.md |
| SLO & SLA | docs/slo.yml (ErrorBudget 43 min/月) |
| オンコールカレンダー | Google Calendar: eventa-oncall |

## オンコール & エスカレーション

### 当番
- 一次担当 (Primary) – PagerDuty rotation events-primary
- 二次担当 (Secondary) – PagerDuty rotation events-secondary
- バックアップ – Slack #sre-oncall

### エスカレーションポリシー
1. アラート発報後 15 分以内に一次対応ない場合、二次担当へ自動エスカレーション
2. アラート発報後 30 分以内に問題解決できなければ、技術責任者へエスカレーション
3. サービス停止が 60 分超過の場合は経営陣への報告

## 共通対応手順

### 1. 決済サービス障害時

**原因**: Stripe/Pay.jp の決済ゲートウェイ障害

**検知方法**:
- 決済失敗率 > 5% のアラート発報
- Stripe Status Page での障害報告
- ユーザー報告（サポートチケット）

**緩和策**:
1. Statusページを確認 (https://status.stripe.com/)
2. システム管理画面でメンテナンスモードを有効化
   ```bash
   curl -X POST https://api.eventa.app/admin/maintenance \
   -H "Authorization: Bearer ${ADMIN_TOKEN}" \
   -d '{"enabled": true, "message": "決済システムメンテナンス中 (30分程度)", "affected_components": ["payment"]}'
   ```
3. フロントエンドにメンテナンスバナー表示
4. Slack #incidents でインシデント宣言

**復旧手順**:
1. Stripeステータス回復確認
2. テスト決済で機能確認
3. メンテナンスモード解除
4. Slackでインシデント終了宣言
5. ポストモーテム記録作成

### 2. データベース応答遅延

**原因**: 高負荷・不適切クエリ・ディスク容量枯渇など

**検知方法**:
- DB レイテンシ > 100ms のアラート
- API P95 レイテンシ > 300ms のアラート
- CPU/メモリ使用率アラート

**緩和策**:
1. RDS/Aurora コンソールでメトリクス確認
   - CPU使用率、メモリ、ディスクIO、接続数
2. スロークエリログ確認
   ```bash
   aws rds download-db-log-file-portion \
   --db-instance-identifier eventa-prod \
   --log-file-name slowquery/mysql-slowquery.log \
   --output text > slow_queries.log
   ```
3. 必要に応じてRead Replicaへの負荷分散
4. 再起動が必要な場合、メンテナンスモードを有効化してから実施

**復旧手順**:
1. 原因となるクエリを特定し、アプリケーションコードを修正またはインデックス追加
2. リソース拡張が必要ならスケールアップ
3. パフォーマンス改善確認後、メンテナンスモード解除

### 3. フロントエンド障害

**原因**: CDN障害、Javascriptエラー、APIとの不整合

**検知方法**:
- Sentry エラー率急増アラート
- エンドユーザーからの報告
- ステータスページアクセス急増

**緩和策**:
1. CDN (CloudFront) キャッシュ削除
   ```bash
   aws cloudfront create-invalidation \
   --distribution-id ${CF_DISTRIBUTION_ID} \
   --paths "/*"
   ```
2. 必要に応じて旧バージョンへのロールバック
   ```bash
   kubectl rollout undo deployment/eventa-frontend
   ```
3. フロントエンドエラーダッシュボードで影響範囲確認

**復旧手順**:
1. フロントエンドコードを修正
2. ホットフィックスのデプロイ
3. エラー率低下確認
4. ポストモーテム実施

## 運用タスク

### 定期的なデータベースメンテナンス

**実施頻度**: 月1回（第3水曜日）

**手順**:
1. メンテナンスウィンドウの事前告知（1週間前）
2. メンテナンスモード有効化
3. バックアップ取得
   ```bash
   aws rds create-db-snapshot \
   --db-instance-identifier eventa-prod \
   --db-snapshot-identifier eventa-prod-pre-maintenance-$(date +%Y%m%d)
   ```
4. スロークエリ解析とインデックス最適化
5. バキューム実行
6. メンテナンスモード解除

### 負荷テスト実施

**実施頻度**: クオータリー（大規模イベント前）

**手順**:
1. 負荷テスト用環境の準備
   ```bash
   terraform apply -var-file=loadtest.tfvars
   ```
2. k6/Locust による負荷シナリオ実行
   ```bash
   k6 run -e ENV=loadtest scripts/load_test_purchase_flow.js --vus 1000 --duration 30m
   ```
3. メトリクス収集・分析
4. ボトルネック特定と対策実施

### バックアップ・リストア訓練

**実施頻度**: 四半期ごと

**手順**:
1. RDSスナップショットからのリストア
2. S3バケットの復元
3. 障害復旧手順の検証
4. リカバリ時間の測定とSLO評価 