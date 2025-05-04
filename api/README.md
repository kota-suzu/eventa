# Eventa - イベント管理システム

Eventaは最新技術を使用した高性能なイベント管理プラットフォームです。本システムはRails APIとNext.jsフロントエンドで構成されています。

## 📚 ドキュメント

詳細な情報は以下のドキュメントを参照してください：

- [開発環境のセットアップと基本操作](docs/development.md)
- [本番環境へのデプロイ手順](docs/deployment.md)
- [Docker環境の詳細説明](docs/docker.md)

## 🚀 クイックスタート

```bash
# 開発環境起動
make dev

# API確認
curl http://localhost:3001/healthz
```

## 🔧 開発環境の仕様

- **Ruby**: 3.3
- **Rails**: 8.0
- **データベース**: MySQL 8.0
- **キャッシュ/ジョブ**: Redis 7 + Sidekiq
- **コード品質**: Standard (Rubocopベースの統一スタイル)

## 📂 プロジェクト構成

- `api/`: Ruby on Rails API
- `frontend/`: Next.js フロントエンド (実装予定)
- `docs/`: プロジェクトドキュメント
- `Makefile`: 共通コマンド
- `docker-compose.yml`: 開発環境設定

## 📝 Docker環境の特記事項

### .dockerignore と開発/本番環境の違い

このプロジェクトでは、Dockerイメージのサイズ最適化のため、`.dockerignore`で`api/spec/`と`api/tmp/`を除外しています。この結果：

- **本番環境向けDockerイメージ**: テストコードは含まれない軽量なイメージになります
- **開発環境**: `docker-compose.yml`の`volumes`マウントにより、`api/spec`はコンテナ内からアクセス可能です
- **CI環境**: GitHub Actionsでは、コードチェックアウトしたものに対して直接テストを実行するため影響ありません

**注意**: もしDocker内で`bundle exec rspec`を実行する場合、以下のいずれかの方法を使用してください：
1. 開発環境では`docker compose exec api bundle exec rspec`（ボリュームマウントにより`spec`ディレクトリにアクセス可能）
2. 独自のCI環境でDockerビルドと同時にテストを実行する場合は、一時的に`.dockerignore`から`api/spec`を除外する必要があります

### Node.js依存性

本番環境でもCSSのコンパイル等のためにNode.jsが必要なため、`Dockerfile.api`のruntimeステージには`nodejs`パッケージを含めています。

## 🧪 テスト

RSpecを使用してテストを実行:

```bash
make test
```

コード品質チェック:

```bash
make lint
```

> **注意**: このプロジェクトでは、Rubocopの直接使用ではなく、Standardを採用しています。Standardは一貫したコーディングスタイルを適用するRubocopベースのツールで、設定の複雑さを軽減します。`make lint`コマンドはStandardを実行します。

## 🔒 環境変数

`.env.example`ファイルを参照して必要な環境変数を設定してください。本番環境では、1Password CLIなどの安全な方法でシークレットを管理することを推奨します。

## 🚢 デプロイ

GitHub ActionsとArgo Rolloutsを使用したCI/CDパイプラインが設定されています。

### Argo Rolloutsによるデプロイ

Argo Rolloutsは、Kubernetesにおける進行的デリバリーを実現するためのツールです。以下にデプロイメントの例を示します：

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

## ❓トラブルシューティング

- **API 502 エラー**: MySQLの起動前にRailsが立ち上がった可能性があります。`docker compose restart api`で解決します。
- **依存関係のエラー**: `make dev`を再実行するか、`docker compose exec api bundle install`を実行してください。

### macOS（特にApple Silicon）でのmysql2 gem依存関係

macOSローカル環境で`bundle install`を実行する場合、mysql2 gemがMySQLクライアントヘッダを見つけられずにエラーになることがあります。解決方法はいくつかあります：

#### 王道の解決策（推奨）：

```bash
# 1) ライブラリをインストール
brew install mysql@8 openssl@3

# 2) PATHを通す
echo 'export PATH="/opt/homebrew/opt/mysql@8/bin:$PATH"' >> ~/.zprofile
source ~/.zprofile

# 3) mysql2ビルド設定を追加
bundle config --local build.mysql2 \
  "--with-mysql-dir=$(brew --prefix mysql@8) \
   --with-openssl-dir=$(brew --prefix openssl@3)"

# 4) 再インストール
bundle install
```

#### 最速の解決策：

すべてDockerコンテナ内で行うことで問題を回避できます：

```bash
# Dockerコンテナ内でコマンドを実行
docker compose exec api bundle exec rails ...
```

#### その他の解消方法：

ライブラリを最小限にインストールする場合：

```bash
brew install mysql-client
bundle config --local build.mysql2 "--with-mysql-dir=$(brew --prefix mysql-client)"
bundle install
```

## 🤝 貢献

1. 機能ブランチを作成 (`git checkout -b feature/amazing-feature`)
2. 変更をコミット (`git commit -m 'Add some amazing feature'`)
3. ブランチをプッシュ (`git push origin feature/amazing-feature`)
4. Pull Requestを作成

## データベース管理

このプロジェクトでは [Ridgepole](https://github.com/ridgepole/ridgepole) を使用してデータベースのスキーマ管理を行っています。通常のRailsマイグレーションの代わりに、`db/Schemafile` で宣言的にスキーマを定義します。

### 基本的な使い方

```bash
# スキーマ変更のシミュレーション
make db-dry-run

# スキーマ変更の適用
make db-apply

# 現在のDBスキーマをエクスポート
make db-export
```

詳細な使用方法は `docs/database/ridgepole_usage.md` を参照してください。

**注意**: 空のSchemafileを適用すると全テーブルが削除される危険があります。必ず先に `make db-export` でスキーマを出力してから編集を始めてください。

## テスト実行

### 通常のテスト実行

```bash
bundle exec rspec
```

### 高速テスト実行

テストの実行を高速化するための機能が実装されています。以下のコマンドを使用します。

```bash
# 全テストの高速実行
bin/fast_test

# 並列テスト実行（4コアの場合）
bin/fast_test -p 4

# 特定のテストファイルのみ実行
bin/fast_test spec/models/ticket_spec.rb

# メモリプロファイリングの実行
bin/fast_test -m spec/models

# focusタグが付いたテストのみ実行
bin/fast_test -f
```

ヘルプを表示するには：

```bash
bin/fast_test -h
```

### 並列テスト実行のための準備

並列テストを実行する前に、データベースを準備します：

```bash
bundle exec rails test:parallel_prepare
```

### テスト環境の最適化について

テスト実行を高速化するために以下の最適化が適用されています：

1. **並列テスト実行**: CPUコア数に合わせた並列実行
2. **データベース最適化**: トランザクション分離レベルの調整、インデックス使用の最適化
3. **メモリ使用量削減**: GC設定の調整、不要なオブジェクト生成の削減
4. **FactoryBot最適化**: 関連オブジェクトの遅延生成、キャッシュの活用
5. **テスト実行時間分析**: 実行時間の長いテストの特定と最適化

---

© 2025 Eventa Team
