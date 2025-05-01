# フロントエンドコンポーネント設計

## 概要

Eventaのフロントエンドは、Next.jsフレームワークを使用したReactコンポーネントで構成されています。このドキュメントでは、主要なコンポーネントの設計原則と使用方法について説明します。

## コンポーネント構造

フロントエンドのコンポーネント構造は以下のように整理されています：

```
frontend/
├── components/      # 再利用可能なUIコンポーネント
├── contexts/        # Reactコンテキスト（状態管理）
├── pages/           # ルーティングとページレイアウト
├── styles/          # CSSモジュールとグローバルスタイル
└── utils/           # ユーティリティ関数
```

## 認証関連コンポーネント

### Auth.module.css

認証関連画面（ログイン、登録など）で使用されるスタイルは `Auth.module.css` で定義されています。これらのスタイルは以下のクラスを提供します：

- `.authContainer` - 認証フォームのコンテナ
- `.title` - フォームタイトル
- `.form` - フォーム要素
- `.formGroup` - フォーム入力グループ
- `.label` - 入力ラベル
- `.input` - 入力フィールド
- `.error` - エラーメッセージ
- `.button` - 送信ボタン
- `.link` - リンクテキスト
- `.apiError` - API関連エラーメッセージ

### 認証コンテキスト（AuthContext）

`AuthContext.js` はアプリケーション全体で認証状態を管理するためのコンテキストを提供します。

```jsx
// 使用例
import { useAuth } from '../contexts/AuthContext';

function MyComponent() {
  const { isAuthenticated, user, login, logout } = useAuth();
  // ...
}
```

## デザインシステム

### 色彩設計

プライマリカラー: `#0070f3`（青）
セカンダリカラー: `#333333`（ダークグレー）
エラーカラー: `#e53e3e`（赤）
背景色: `#ffffff`（白）

### タイポグラフィ

フォントファミリー: システムフォント（-apple-system, BlinkMacSystemFont, Segoe UI, Roboto, など）
ベースフォントサイズ: 16px
見出しスケール: 1.25倍

## コンポーネントの使用例

### Header コンポーネント

```jsx
import Header from '../components/Header';

function MyPage() {
  return (
    <div>
      <Header />
      <main>ページコンテンツ</main>
    </div>
  );
}
```

## モバイル対応

レスポンシブデザインは以下のブレークポイントで実装されています：

- モバイル: 〜767px
- タブレット: 768px〜1023px
- デスクトップ: 1024px〜

## バージョン互換性に関する注意

Next.js 15.3.1はReact 18.2.0との互換性があります。React 19.x系はサポートされていないため、依存関係のアップデート時には注意が必要です。

## 今後の拡張計画

1. コンポーネントライブラリ（Storybook）の導入
2. ダークモードサポート
3. テーマカスタマイズ機能 