# 開発環境のセットアップと基本操作

## 🚀 開発環境のセットアップ

### 必要条件

- Docker と Docker Compose
- Git

### クイックスタート

1. リポジトリをクローン:
   ```bash
   git clone git@github.com:your-organization/eventa.git
   cd eventa
   ```

2. 環境を起動:
   ```bash
   make dev
   ```
   これにより、以下の処理が実行されます:
   - Dockerコンテナのビルドと起動
   - データベースの準備 (マイグレーションとシード)
   
3. サービスの確認:
   - API: http://localhost:3001/healthz
   - API Routes: http://localhost:3001/rails/info/routes (開発環境のみ)
   - フロントエンド: http://localhost:3000 (実装後)

### 利用可能なコマンド

Makefileを使用して一般的なタスクを実行できます:

```bash
make help      # 利用可能なコマンド一覧
make dev       # 開発環境を起動
make reset-db  # データベースをリセット
make lint      # コード品質チェック (Standardを使用)
make test      # テストを実行
make ci        # lintとtestを連続実行
```

### 本番環境に近い構成での起動

Workerプロセスを分離して起動する場合は、以下のコマンドを使用します:

```bash
docker compose --profile production-like up
```

このコマンドは、APIとWorkerプロセスを別々のコンテナで実行し、本番環境に近い構成をシミュレーションします。

## 🔧 開発環境の仕様

- **Ruby**: 3.3
- **Rails**: 8.0
- **データベース**: MySQL 8.0
- **キャッシュ/ジョブ**: Redis 7 + Sidekiq
- **コード品質**: Standard (Rubocopベースの統一スタイル)

## 📝 GitHub Codespaces / Dev Container 対応

このプロジェクトはDev Containerに対応しており、VSCode Dev ContainersまたはGitHub Codespacesでの開発をサポートしています。これにより、ローカル環境の設定なしに開発を始めることができます。

1. リポジトリをGitHubからクローン
2. VSCodeで「Open in Container」または「Open in Codespace」を選択
3. 自動的に開発環境がセットアップされます

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
``` 