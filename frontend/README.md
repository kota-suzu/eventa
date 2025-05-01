# Eventa フロントエンド

Eventa イベント管理システムのフロントエンドアプリケーションです。Next.jsで構築されており、Eventaバックエンド API と連携して動作します。

## 機能

- イベントの作成と管理
- イベント一覧の表示
- イベント詳細の閲覧
- ユーザー認証

## 開発環境のセットアップ

```bash
# 依存関係のインストール
npm install

# 開発サーバーの起動
npm run dev
```

開発サーバーは http://localhost:3000 で起動します。

## ビルド方法

```bash
# 本番用ビルド
npm run build

# 本番モードでの起動
npm start
```

## 技術スタック

- Next.js - Reactフレームワーク
- CSS Modules - スタイリング
- Fetch API - バックエンドとの通信

## プロジェクト構造

```
frontend/
├── components/     # 再利用可能なコンポーネント
├── pages/          # アプリケーションのページ/ルート
├── public/         # 静的ファイル
├── styles/         # グローバルスタイルとCSSモジュール
└── utils/          # ユーティリティ関数
```

## 環境変数

`.env.local` ファイルを作成し、以下の環境変数を設定できます：

```
NEXT_PUBLIC_API_URL=http://localhost:3001 # APIのURL
```

## Docker での実行

プロジェクトルートの `docker-compose.yml` を利用してバックエンドとともに起動できます。

```bash
# プロジェクトルートディレクトリで実行
make dev
```

---

© 2025 Eventa Team 