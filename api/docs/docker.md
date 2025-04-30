# Docker環境の詳細説明

## 🐳 Docker構成

本プロジェクトは、以下のサービスで構成されています：

- **api**: Rails APIサーバー (Puma)
- **worker**: Sidekiqワーカー（プロファイル設定で分離可能）
- **db**: MySQL 8.0データベース
- **redis**: Redis 7キャッシュ/ジョブストレージ

## 📦 Dockerfileの構成

### マルチステージビルド

`Dockerfile.api`はマルチステージビルドを採用しています：

1. **builder**: 依存関係のインストールとアセットのコンパイルを行う
2. **runtime**: 実行に必要な最小限のパッケージのみを含む軽量イメージ

この構成により、本番イメージのサイズを最小限に抑え、セキュリティリスクを軽減しています。

```dockerfile
# ビルドステージ - gemのビルドとインストールを行う
FROM ruby:3.3-slim AS builder
# ... ビルド時の依存関係のインストール、gemのインストール等 ...

# 本番用ステージ - 必要なランタイム依存関係のみ含める
FROM ruby:3.3-slim AS runtime
# ... 最小限のランタイム依存関係のみインストール ...
```

### 注意点

- **Node.js依存**: 本番環境でCSSのコンパイルなどにNode.jsが必要なため、`nodejs`パッケージをruntimeステージにも含めています。
- **アセットコンパイル**: アセットは`builder`ステージでコンパイルし、結果のみを`runtime`ステージにコピーしています。

## 🔍 docker-compose.yml

開発環境では`docker-compose.yml`を使用して、以下のように構成しています：

```yaml
services:
  db:
    image: mysql:8.0
    # ... 設定 ...
  
  redis:
    image: redis:7-alpine
    # ... 設定 ...
  
  api:
    build: 
      context: .
      dockerfile: Dockerfile.api
    # ... 設定 ...
    
  worker:
    profiles: ["production-like"]  # 本番環境シミュレーション時のみ起動
    # ... 設定 ...
```

### プロファイル

`profiles`機能を使用して、一部のサービスを特定の目的でのみ起動できるようにしています：

```bash
# 標準の開発環境（APIプロセスがSidekiqも内部で起動）
docker compose up

# 本番環境に近い構成（Sidekiqを別プロセスで起動）
docker compose --profile production-like up
```

## 📇 .dockerignore

コンテナビルド時に不要なファイルを除外し、ビルド速度の向上とイメージサイズの削減を図っています：

```
# テストディレクトリは開発時にはホストからマウント
# /spec/

# 一時ファイル
/tmp/

# Git関連ファイル
/.git/
```

> **注**: `/spec/`ディレクトリのイメージ除外は、Docker内でテストを実行する場合に問題になる可能性があります。必要に応じて`.dockerignore`からコメントアウトしてください。

## 🔄 ヘルスチェック

各サービスには適切なヘルスチェックが設定されており、依存関係の起動順序を制御しています：

```yaml
db:
  healthcheck:
    test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "--silent"]
    timeout: 5s
    retries: 10

redis:
  healthcheck:
    test: ["CMD", "redis-cli", "ping"]
    interval: 1s
    timeout: 3s
    retries: 30
```

APIコンテナは、これらのヘルスチェックが成功した後にのみ起動します：

```yaml
api:
  depends_on:
    db:
      condition: service_healthy
    redis:
      condition: service_healthy
```

## 🔧 ボリューム

パフォーマンスと永続性のために、いくつかのボリュームを設定しています：

```yaml
volumes:
  db_data:  # データベースデータの永続化
  bundle_cache:  # Rubygemのキャッシュ
  yarn_cache:  # Yarnパッケージのキャッシュ
```

## 🖥️ Dev Containers / Codespaces 対応

VSCode Dev ContainersまたはGitHub Codespacesと互換性のある`.devcontainer.json`を提供：

```json
{
  "name": "eventa",
  "dockerComposeFile": "docker-compose.yml",
  "service": "api",
  "workspaceFolder": "/app",
  "postStartCommand": "bin/setup || true",
  "mounts": [ 
    "source=eventa_gems,target=/usr/local/bundle,type=volume",
    "source=eventa_yarn,target=/home/vscode/.cache/yarn,type=volume",
    "source=eventa_node_modules,target=/app/.node_modules_cache,type=volume"
  ],
  "postAttachCommand": "yarn install --immutable --silent"
}
``` 