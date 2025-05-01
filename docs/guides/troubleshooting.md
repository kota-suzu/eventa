# トラブルシューティングガイド

このドキュメントでは、Eventaプロジェクトで発生する可能性のある一般的な問題とその解決策を紹介します。

## フロントエンドの問題

### 1. Module not found エラー

#### 症状

```
Module not found: Can't resolve '[MODULE_NAME]'
```

このエラーは、依存関係が見つからないか、インポートパスが間違っている場合に発生します。

#### 解決策

**ローカル開発の場合：**

```bash
# 依存関係をインストール
cd frontend
npm install [MODULE_NAME]

# または既存の依存関係を再インストール
rm -rf node_modules package-lock.json
npm install
```

**Docker開発の場合：**

```bash
# コンテナ内でパッケージをインストール
docker compose exec frontend npm install [MODULE_NAME] --save

# 問題が解決しない場合はボリュームを削除して再構築
docker compose down -v
docker compose up -d --build frontend
```

### 2. React バージョン互換性の問題

#### 症状

```
TypeError: Cannot read properties of undefined (reading 'recentlyCreatedOwnerStacks')
```

このエラーは、Next.jsとReactのバージョンに互換性がない場合に発生します。

#### 解決策

```bash
# package.jsonでReactとReact DOMのバージョンを18.2.0に修正
"dependencies": {
  "react": "^18.2.0",
  "react-dom": "^18.2.0"
}

# 依存関係を再インストール
cd frontend
rm -rf node_modules package-lock.json
npm install
```

**Docker開発の場合：**

```bash
# package.jsonを修正後
docker compose down -v
docker compose up -d --build frontend
```

### 3. CSS モジュールが見つからない

#### 症状

```
Module not found: Can't resolve '../styles/[FILE_NAME].module.css'
```

#### 解決策

1. 参照しているCSSモジュールファイルが存在することを確認
2. 存在しない場合は作成

```bash
# 例: Auth.module.cssを作成
touch frontend/styles/Auth.module.css
```

```css
/* 基本的なスタイル定義を追加 */
.authContainer {
  max-width: 500px;
  margin: 60px auto;
  padding: 2rem;
  /* 他のスタイル */
}
```

## バックエンドの問題

### 1. データベース接続エラー

#### 症状

```
PG::ConnectionBad: could not connect to server
```

または

```
Mysql2::Error: Access denied for user
```

#### 解決策

```bash
# 環境変数が正しく設定されていることを確認
cat .env.example

# データベースコンテナが実行中か確認
docker compose ps

# データベースをリセット
make reset-db
```

### 2. APIエンドポイントが見つからない

#### 症状

フロントエンドからAPIへのリクエストが404または500エラーを返す。

#### 解決策

1. APIルートが正しく定義されているか確認
2. APIサーバーが実行中か確認
3. CORS設定が正しいか確認

```bash
# APIログを確認
make logs

# ルート一覧を表示
make routes
```

## Docker関連の問題

### 1. ボリュームマウントの問題

#### 症状

コンテナ内で行った変更が反映されない、またはコンテナが古いファイルバージョンを使用している。

#### 解決策

```bash
# ボリュームを削除して再構築
docker compose down -v
docker compose up -d --build
```

### 2. ポート競合

#### 症状

```
Error starting userland proxy: Bind for 0.0.0.0:3000 failed: port is already allocated
```

#### 解決策

1. 競合しているサービスを停止
2. docker-compose.ymlでポートマッピングを変更

```yaml
services:
  frontend:
    ports: ["3010:3000"]  # 別のポートを使用
```

## その他のヒント

- **キャッシュ問題**: ブラウザのハード更新（Ctrl+F5またはCmd+Shift+R）を試す
- **ログ確認**: 問題解決の最初のステップは常に関連ログを確認すること
- **環境変数**: 必要な環境変数がすべて設定されているか確認
- **スタックトレース**: エラーログのスタックトレースを注意深く読むことで、問題の根本原因を特定できることが多い 