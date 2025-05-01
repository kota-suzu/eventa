# Docker開発環境ガイド

## 概要

EventaプロジェクトはDocker Composeを使用した開発環境を提供しています。このガイドでは、Docker環境のセットアップ方法、使用方法、および一般的な問題のトラブルシューティングについて説明します。

## 必要条件

- Docker Desktop（または同等のDocker環境）
- docker-compose
- Make（オプション、便利なショートカットコマンドのため）

## 開発環境の起動

プロジェクトルートディレクトリで以下のコマンドを実行します：

```bash
# Makefileを使用する場合
make dev

# Makefileを使用しない場合
docker compose up -d --build
docker compose exec api bin/rails db:prepare
```

このコマンドは以下のサービスを起動します：

- **db**: MySQL 8.0データベース
- **redis**: Redis 7キャッシュサーバー
- **api**: Rails APIバックエンド
- **frontend**: Next.jsフロントエンド

## 個別サービスの起動

必要に応じて個別のサービスを起動できます：

```bash
# フロントエンドのみ
make frontend

# APIのみ（データベースとRedisに依存）
docker compose up -d api
```

## ログの確認

各サービスのログを確認するには：

```bash
# フロントエンドのログ
make frontend-logs

# APIのログ
make logs

# または直接docker-composeを使用
docker compose logs -f [service_name]
```

## コンテナへのアクセス

コンテナ内でコマンドを実行するには：

```bash
# Rails コンソール
make console

# APIコンテナのシェル
make shell

# フロントエンドコンテナのシェル
docker compose exec frontend sh
```

## 開発ワークフロー

1. コードを変更する（ローカルファイルシステム上）
2. 変更はホットリロードされ、自動的にアプリケーションに反映されます
3. ブラウザで確認（API: http://localhost:3001, フロントエンド: http://localhost:3000）

## ボリュームとマウント

Docker Composeは以下のボリュームを使用します：

- **db_data**: データベースの永続化
- **bundle_cache**: Ruby gemのキャッシュ
- **yarn_cache**: Yarn依存関係のキャッシュ
- **frontend_node_modules**: フロントエンドの依存関係

## 依存関係の管理

### バックエンド（Rails）

新しいgemを追加する場合：

```bash
docker compose exec api bundle add [gem_name]
```

### フロントエンド（Next.js）

新しいnpmパッケージを追加する場合：

```bash
docker compose exec frontend npm install [package_name] --save
```

## トラブルシューティング

### 依存関係の問題

依存関係に関する問題が発生した場合は、ボリュームを削除して再構築することが有効な場合があります：

```bash
docker compose down -v
docker compose up -d --build
```

### ポートの競合

既存のサービスと競合する場合、ポートマッピングを変更できます：

```yaml
# docker-compose.yml（編集後）
services:
  frontend:
    ports: ["3010:3000"]  # ローカルの3010ポートにマッピング
```

### Node.jsとReactの互換性問題

Next.js 15.3.1はReact 18.2.0と互換性があります。React 19.x系を使用すると、`recentlyCreatedOwnerStacks`のような内部プロパティに関連するエラーが発生する可能性があります。

## Docker使用のメリット

1. **環境の一貫性**: 全ての開発者が同じ環境で作業できます
2. **依存関係の分離**: ローカルマシンを汚さずに依存関係を管理できます
3. **マルチサービス開発**: APIとフロントエンドを同時に開発できます

## DockerなしでNext.jsを開発する

Docker使用が望ましくない場合は、ローカルで直接Next.jsを実行することもできます：

```bash
cd frontend
npm install
npm run dev
```

ただし、この場合、API接続の設定が必要になる場合があります。 