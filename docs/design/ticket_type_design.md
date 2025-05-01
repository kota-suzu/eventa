# FR-01: チケットタイプ管理 — Design Doc (v0.1)

**関連機能仕様**: eventa 機能仕様書 §5 FR-01  
**作成日**: 2025-04-30  
**作成者**: チケットチーム  

## 目的 (Why)
複数価格・在庫・販売期間 を柔軟に設定できるチケットタイプ管理機能を実装し、運営が Early-Bird・一般・学生・無料などのチケットをノーコードで発行できるようにする。
無料チケット は price_cents = 0 として同一モデルで扱い、決済フローをスキップすることでコード分岐を最小化する。

## スコープ (Scope)
- チケットタイプ CRUD UI + API
- 在庫・販売期間による 自動販売状態 切替 (準備中→販売中→販売終了 / 売切れ)
- price_cents = 0 の無料チケット発行 & 受付
- Stripe/Pay.jp 連携 (有料のみ)

**Non-Scope**: 座席指定、定期課金、グループ購入は別 FR で扱う

## データモデル

### TicketType

| カラム | 型 | 制約 | 説明 |
|-------|-----|-----|------|
| id | BIGINT PK | AUTO | |
| event_id | BIGINT FK | NOT NULL | イベントID |
| name | VARCHAR(100) | NOT NULL | チケット名 |
| description | TEXT | | 説明文 |
| price_cents | INTEGER | NOT NULL, >= 0 | 価格（円）* 100 |
| currency | CHAR(3) | NOT NULL, DEFAULT 'JPY' | 通貨コード |
| quantity | INTEGER | NOT NULL, >= 0 | 在庫数（0=無制限） |
| sales_start_at | DATETIME | NOT NULL | 販売開始日時 |
| sales_end_at | DATETIME | NOT NULL | 販売終了日時 |
| status | ENUM | NOT NULL | 準備中/販売中/売切/終了 |
| created_at | DATETIME | NOT NULL | |
| updated_at | DATETIME | NOT NULL | |

## API 設計

### チケットタイプ一覧取得
```
GET /api/v1/events/:event_id/ticket_types
```

#### レスポンス例
```json
{
  "data": [
    {
      "id": "1",
      "type": "ticket_types",
      "attributes": {
        "name": "早割チケット",
        "description": "先着100名様限定の早期割引チケット",
        "price_cents": 100000,
        "currency": "JPY",
        "quantity": 100,
        "remaining": 45,
        "sales_start_at": "2025-01-01T00:00:00Z",
        "sales_end_at": "2025-01-31T23:59:59Z",
        "status": "on_sale"
      }
    }
  ],
  "meta": {
    "total": 1
  }
}
```

### チケットタイプ作成
```
POST /api/v1/events/:event_id/ticket_types
```

#### リクエスト例
```json
{
  "ticket_type": {
    "name": "学生チケット",
    "description": "学生証提示で入場可能",
    "price_cents": 50000,
    "quantity": 200,
    "sales_start_at": "2025-02-01T00:00:00Z",
    "sales_end_at": "2025-04-30T23:59:59Z"
  }
}
```

## UI設計

### チケットタイプ一覧画面
- テーブルビューで一覧表示
- 各行にアクション（編集・無効化・複製）
- 在庫・販売状況をバッジで視覚的に表示
- ソート・フィルター機能

### チケットタイプ編集モーダル
- 名称・説明
- 価格設定（無料/有料切替）
- 在庫設定（数量制限あり/なし）
- 販売期間（カレンダーピッカー）
- 高度な設定（表示順、グループ化など）

## 検討事項・デザイン判断

### 無料チケット処理
- **決定**: price_cents = 0 の場合は決済をスキップし直接チケット発行
- **理由**: コードパスを単純化し、決済処理のコード分岐を避ける

### 在庫管理方式
- **検討案1**: 在庫数をプラスから減らす方式
- **検討案2**: 販売数をゼロから増やす方式
- **決定**: 検討案1を採用し、quantity - tickets.count でリアルタイム残数計算
- **理由**: キャンセル時の在庫戻し処理が単純化される 