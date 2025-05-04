# フロントエンドとAPIの統合ガイド

このドキュメントでは、フロントエンドからバックエンドAPIを正しく接続するためのベストプラクティスと、発生しやすい問題の解決方法を説明します。

## 環境変数の設定

Dockerコンテナ間の通信と、ブラウザからの通信では、APIのベースURLが異なる可能性があります：

```
# Docker内からの接続（フロントエンドコンテナ→APIコンテナ）
NEXT_PUBLIC_API_URL=http://api:3000

# ブラウザからの直接接続（開発時）
NEXT_PUBLIC_API_URL=http://localhost:3001
```

## APIクライアントの実装

このプロジェクトでは2つのAPIクライアント実装があります：

1. `utils/auth.js` - 認証関連のAPIリクエスト用
2. `utils/api.js` - 一般的なAPIリクエスト用

これらのクライアントは以下の点に注意して実装されています：

```javascript
// 環境変数からAPIのベースURLを取得
const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001';
// APIパスのプレフィックス
const API_PATH_PREFIX = '/api/v1';

// APIクライアントの作成
const apiClient = axios.create({
  baseURL: API_BASE_URL.endsWith('/')
    ? `${API_BASE_URL.slice(0, -1)}${API_PATH_PREFIX}`
    : `${API_BASE_URL}${API_PATH_PREFIX}`,
  headers: {
    'Content-Type': 'application/json',
  },
  withCredentials: true, // CORS対応
});
```

## 一般的な問題と解決策

### 1. 不正なURLフォーマット

**問題**: `/api:3000/api/v1/...` のような不正なURLにアクセスしようとするエラー

**原因**:

- 環境変数`NEXT_PUBLIC_API_URL`が正しく設定されていない
- プロトコル（`http://`）が欠落している
- URL結合時の重複パス

**解決策**:

- 環境変数には必ずプロトコルを含める: `http://api:3000`
- URL結合時に重複スラッシュを削除
- Next.jsのrewrites機能を使ってプロキシを設定

### 2. CORS（Cross-Origin Resource Sharing）エラー

**問題**: APIへのリクエストが`Access-Control-Allow-Origin`エラーで失敗する

**解決策**:

- API側で適切なCORS設定（`config/initializers/cors.rb`）
- フロントエンドのAPIリクエストで`withCredentials: true`を設定
- Next.jsのrewrites機能を使ってプロキシを設定

### 3. 環境による違い

**開発環境**:

- Next.jsの開発サーバーはHMR（Hot Module Replacement）を使用
- rewrites機能を使ってAPIプロキシを設定可能

**本番環境**:

- SSR（Server-Side Rendering）の場合：サーバー側とクライアント側でベースURLが異なる場合がある
- 静的ビルド（Static Generation）の場合：すべてのAPIリクエストはクライアント側

## Dockerを使用する場合の特別な注意点

1. **コンテナ間通信**:

   - コンテナ名（`api`）をホスト名として使用
   - 適切なポート（`3000`）を指定

2. **ボリュームマウント**:

   - 開発環境では、ソースコードの変更が即座に反映されるようにボリュームマウントを使用

3. **環境変数**:
   - `docker-compose.yml`で環境変数を設定
   - `.env.local`ファイルでのオーバーライドに注意

## デバッグツール

API接続の問題を診断するために、`/debug`ページを用意しています：

- API設定の確認
- テスト接続機能
- 異なるリクエスト方法のテスト
- 相対/絶対パスの切り替え

## ベストプラクティス

1. **環境変数を適切に管理**:

   - 開発/テスト/本番で異なる値を使用
   - デフォルト値を設定（環境変数がない場合のフォールバック）

2. **一貫性のあるAPIパス管理**:

   - パスプレフィックス（`/api/v1`）を一箇所で定義
   - エンドポイントパスは相対パスで記述

3. **エラーハンドリング**:

   - ネットワークエラーの詳細なログ出力
   - ユーザーフレンドリーなエラーメッセージ

4. **プロキシの活用**:
   - CORS問題の回避
   - 環境に依存しないURL構造
