# eventa リリースノート — v0.1.0 (MVP Alpha)

**リリース日**: 2025-05-01  
**対象環境**: Staging / Internal Pilot  
**ビルド番号**: 20250501.0

## 🎉 主要な新機能

| カテゴリ | 機能 | 説明 |
|---------|------|------|
| チケット | チケットタイプ作成 | 容量・価格・販売期間を GUI で設定可能 |
| チケット | QR チケット発行 | Stripe / Pay.jp 決済完了時に動的 QR を生成し、メール & LINE で配信 |
| 受付 | QR 受付スキャン | モバイル PWA でカメラを使用し 1 秒以内にチェックイン処理 |
| 座席 | 座席マップ編集 | SVG ベースのドラッグ & ドロップで座席配置を編集可能 |
| 登壇者 | 登壇者プロフィール管理 | 画像・SNS リンクを含むプロフィール登録と公開 API でサイト埋め込み |
| 通知 | LINE / Slack 通知 | 決済完了・イベント前日リマインド・当日案内を自動送信 |

## 🛠 改善点

- API レスポンスに meta.total を追加しフロントのページネーション負荷を軽減
- QR 受付エンドポイントを POST /check_in → PUT /tickets/{id}/check_in に変更し REST 準拠
- テンプレートメールをマルチパート (HTML/プレーンテキスト) 対応化
- CSV エクスポート時のシフト JIS エンコーディングサポート追加
- iOS 15+ でのカメラアクセス権限フローを改善

## 🐛 バグ修正

- Safariでフォームの自動入力が機能しない問題を修正
- タイムゾーンを考慮せず UTC 表示されていた日付表示を修正
- 座席選択後の戻るボタンで在庫が解放されない問題を修正
- 決済キャンセル時にエラーメッセージが表示されない問題を修正
- Webhook 受信時のタイムアウト対策として非同期処理に変更

## 💡 既知の問題

- IE11 は非サポート（現代的ブラウザのみサポート）
- オフラインモード時に座席指定選択ができない制限あり
- 一部の無線 LAN 環境で QR スキャンが遅延する場合あり（調査中）
- LINE 通知がまれに遅延する現象を確認（LINE 社へ問い合わせ中）

## 📋 API の変更点

### 追加された API

- `GET /api/v1/events/{id}/stats` - イベント統計データ取得
- `POST /api/v1/tickets/{id}/transfer` - チケット譲渡機能
- `GET /api/v1/speakers` - 登壇者一覧取得

### 変更された API

- `GET /api/v1/events` - `include` パラメータでリレーション取得可能に
- `POST /api/v1/tickets` - `notify_channels` パラメータで通知方法を指定可能に

### 非推奨 API（次回リリースで削除予定）

- `POST /api/v1/check_in` - `PUT /api/v1/tickets/{id}/check_in` へ移行

## 📊 パフォーマンス改善

- API レスポンスタイム P95: 340ms → 270ms
- フロントエンドロード時間: 2.1秒 → 1.7秒
- Lighthouse パフォーマンススコア: 76 → 92

## 📅 今後の予定

- 次回リリース (v0.2.0): グループチケット購入、カスタムフォーム、キャンセルポリシー設定
- 7月リリース予定: 複数イベント一括管理、レポートエクスポート機能

## 📚 ドキュメント

- [API リファレンス](https://docs.eventa.app/api)
- [開発者ガイド](https://docs.eventa.app/dev)
- [運用マニュアル](https://docs.eventa.app/ops)

## 📞 サポート

- サポートチケット: support@eventa.app
- 緊急問い合わせ: Slack #eventa-support