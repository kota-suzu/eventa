# 本番環境へのデプロイ手順

## 🚢 デプロイ方法

本プロジェクトでは、GitHub ActionsとKamalを使用したCI/CDパイプラインが設定されています。

### Kamalによるデプロイ

Kamalは、Dockerコンテナを使用した簡単なデプロイツールです。以下の手順でデプロイします：

1. 必要な環境変数を設定:
   ```bash
   # Kamal用のデプロイ設定
   export KAMAL_REGISTRY_PASSWORD=<Dockerレジストリパスワード>
   ```

2. デプロイコマンドを実行:
   ```bash
   bin/kamal deploy
   ```

3. ロールバックが必要な場合:
   ```bash
   bin/kamal rollback
   ```

### Argo Rolloutsによるデプロイ

Kubernetes環境では、Argo Rolloutsを使用した進行的デリバリーを設定可能です：

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: eventa-api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: eventa-api
  template:
    metadata:
      labels:
        app: eventa-api
    spec:
      containers:
      - name: eventa-api
        image: eventa-api:latest
        ports:
        - containerPort: 3000
        env:
        - name: RAILS_ENV
          value: production
        - name: GIT_SHA
          value: "{{.Values.gitSha}}"
  strategy:
    canary:
      steps:
      - setWeight: 20
      - pause: {duration: 5m}
      - setWeight: 50
      - pause: {duration: 5m}
```

この設定により、新バージョンは最初に20%のトラフィックを受け、5分後に50%に増加、さらに5分後に100%となります。これにより、問題が発生した場合のリスクを最小限に抑えることができます。

## 🔒 環境変数

本番環境では、以下の環境変数を設定する必要があります：

```
# 基本設定
RAILS_ENV=production
RAILS_MASTER_KEY=<config/master.keyの内容>
DATABASE_URL=mysql2://username:password@hostname:3306/database
REDIS_URL=redis://hostname:6379/0

# パフォーマンス調整
WEB_CONCURRENCY=2
SIDEKIQ_CONCURRENCY=10
MALLOC_ARENA_MAX=2
```

### シークレット管理

本番環境のシークレット管理には、以下のいずれかの方法を推奨します：

1. **Kamalシークレット**:
   ```bash
   # シークレットの設定
   bin/kamal secrets set RAILS_MASTER_KEY
   ```

2. **1Password / HashiCorp Vault**:
   Kamalは1Passwordなどのシークレット管理ツールとの統合をサポートしています。
   
   ```bash
   kamal secrets fetch --adapter 1password --account your-account --from Vault/Item
   ```

## 📜 デプロイ後の確認

デプロイ完了後、以下の確認を行ってください：

1. ヘルスチェックエンドポイントにアクセス:
   ```
   curl https://your-domain.com/healthz
   ```

2. ログの確認:
   ```bash
   bin/kamal logs -f
   ```

3. Sidekiqダッシュボードのアクセス:
   ```
   https://your-domain.com/sidekiq
   ```

## 🔄 メンテナンスモード

メンテナンス中にサイトを一時的に停止する場合：

```bash
# メンテナンスモード開始
bin/kamal accessory exec nginx "cp /etc/nginx/maintenance_on.conf /etc/nginx/conf.d/default.conf && nginx -s reload"

# メンテナンスモード終了
bin/kamal accessory exec nginx "cp /etc/nginx/default.conf /etc/nginx/conf.d/default.conf && nginx -s reload"
``` 