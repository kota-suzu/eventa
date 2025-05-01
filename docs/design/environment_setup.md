# eventa 開発環境構築 Design Doc (v0.1)

**ステータス**: Draft 0.2  
**作成日**: 2025-04-30  
**作成者**: DevEnv WG  

## 目的 (Why)
開発者が 10 分以内 に eventa のローカル環境を立ち上げ、主要ユースケース (チケット発行→QR 受付) をオフラインで検証できるようにする。環境差分による "動く／動かない" 問題を排除し、CI/CD と同一の Docker イメージで整合性を保つ。

## 対象範囲 (Scope)
- macOS / Linux / Windows (WSL2) 上でのローカル開発
- Docker Desktop / Podman 対応
- VS Code Dev Containers / GitHub Codespaces 対応

## 技術スタック (Local)

| サービス | イメージ | ポート | 備考 |
|---------|---------|------|------|
| Rails API | ruby:3.3-alpine | 3000 | API 専用 (Puma) |
| Next.js | node:20-alpine | 3001 | Web モック (Hot Reload) |
| DB | mysql:8.0 | 3306 | 開発用 DB |
| Redis | redis:7.0-alpine | 6379 | セッション・キャッシュ |
| Mailhog | mailhog/mailhog | 8025 | メール送信テスト用 |
| MinIO | minio/minio | 9000, 9001 | S3互換ストレージ |

## 開発環境セットアップ手順

### 前提条件
- Docker Desktop (Mac/Win) または docker + docker-compose (Linux)
- Git
- VS Code (推奨)

### 初回セットアップ手順
1. リポジトリをクローン
   ```bash
   git clone https://github.com/organization/eventa.git
   cd eventa
   ```

2. 環境変数ファイルの作成
   ```bash
   cp .env.example .env
   ```

3. コンテナのビルドと起動
   ```bash
   docker-compose up -d
   ```

4. データベースのセットアップ
   ```bash
   docker-compose exec api bin/rails db:setup
   ```

5. シードデータの投入
   ```bash
   docker-compose exec api bin/rails db:seed
   ```

## 開発ワークフロー

### Docker Compose でのサービス制御
- 起動: `docker-compose up -d`
- 停止: `docker-compose down`
- ログ表示: `docker-compose logs -f [service]`
- 再起動: `docker-compose restart [service]`

### よく使うコマンド
- Rails コンソール: `docker-compose exec api bin/rails c`
- テスト実行: `docker-compose exec api bin/rails test`
- マイグレーション: `docker-compose exec api bin/rails db:migrate`

## VS Code Dev Container の活用
`.devcontainer.json` ファイルを用意し、VS Code の Remote Containers 機能を活用することで:
- 統一された開発環境
- プロジェクト固有の拡張機能の自動インストール
- Git 認証情報の自動共有

```json
{
  "name": "Eventa Development",
  "dockerComposeFile": ["docker-compose.yml"],
  "service": "api",
  "workspaceFolder": "/app",
  "extensions": [
    "rebornix.ruby",
    "castwide.solargraph",
    "kaiwood.endwise",
    "dbaeumer.vscode-eslint"
  ]
}
```

## テストデータとモックサービス

### テストデータ
開発環境には以下のテストデータが自動で作成されます:
- サンプルイベント (3件)
- テストユーザー (admin/organizer/guest)
- チケットタイプ (有料/無料)

### モックサービス
- Stripe Webhook: 開発環境では Stripe CLI による webhook 転送機能を組み込み
- LINE/Slack: 開発環境用の Mock サーバーを用意

## 開発環境と本番環境の差異

| 機能 | 開発環境 | 本番環境 |
|-----|----------|---------|
| 決済 | Stripe テストモード | Stripe 本番モード |
| メール | Mailhog | AWS SES |
| ストレージ | MinIO (ローカル) | AWS S3 |
| キャッシュ | ローカル Redis | ElastiCache |

## モバイル受付アプリ開発
モバイル受付アプリ (PWA) の開発は通常の開発フローと同様に行い、ブラウザのデバイスエミュレーションで検証可能。実機テストの際は:

1. 開発PCとモバイルを同一ネットワークに接続 
2. ngrok を使用してローカル環境を一時公開
   ```bash
   ngrok http 3000
   ```
3. 表示される一時URLにモバイルからアクセス 