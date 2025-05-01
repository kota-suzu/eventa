# eventa API リファレンス (v0.1)

**ベース URL**: https://api.eventa.app

本 API は REST/JSON で提供されます。日時はすべて ISO-8601（UTC）です。

## 認証と共通仕様

| 項目 | 内容 |
|-----|------|
| 認証方式 | Bearer JWT (Authorization: Bearer \<token\>) |
| ロール | admin, organizer, guest（JWT claim: role） |
| ページネーション | page / per_page クエリ、レスポンスに meta.total 等を含む |
| エラー形式 | status, error, message, details[] |
| レート制限 | 100 req/min/IP (HTTP 429 で通知) |

## エンドポイント一覧

### イベント系 API

| リソース | メソッド | パス | 説明 |
|---------|---------|-----|------|
| Events | GET | /api/v1/events | 公開イベント一覧取得 |
| | GET | /api/v1/events/{id} | 単一イベント詳細 |
| | POST | /api/v1/events | イベント作成 (organizer) |
| | PATCH | /api/v1/events/{id} | イベント更新 (organizer) |
| | DELETE | /api/v1/events/{id} | イベント削除 (organizer) |

### チケット系 API

| リソース | メソッド | パス | 説明 |
|---------|---------|-----|------|
| TicketTypes | GET | /api/v1/events/{event_id}/ticket_types | チケットタイプ一覧 |
| | POST | /api/v1/events/{event_id}/ticket_types | チケットタイプ作成 (organizer) |
| | PATCH | /api/v1/ticket_types/{id} | チケットタイプ更新 (organizer) |
| | DELETE | /api/v1/ticket_types/{id} | チケットタイプ削除 (organizer) |
| Tickets | POST | /api/v1/ticket_types/{id}/purchase | チケット購入処理 |
| | GET | /api/v1/tickets/{id} | チケット詳細取得 |
| | PATCH | /api/v1/tickets/{id}/cancel | チケットキャンセル |

### 受付系 API

| リソース | メソッド | パス | 説明 |
|---------|---------|-----|------|
| CheckIn | PUT | /api/v1/tickets/{id}/check_in | QR チェックイン処理 |
| | GET | /api/v1/events/{event_id}/check_ins | チェックイン履歴取得 |
| | POST | /api/v1/tickets/validate | QRコード検証（オフライン用） |

## リクエスト・レスポンス例

### イベント一覧取得

```
GET /api/v1/events?page=1&per_page=10
```

#### レスポンス例
```json
{
  "data": [
    {
      "id": "1",
      "type": "events",
      "attributes": {
        "name": "Tech Conference 2025",
        "description": "最新技術動向の紹介",
        "start_at": "2025-06-01T10:00:00Z",
        "end_at": "2025-06-01T18:00:00Z",
        "venue": "東京カンファレンスセンター",
        "status": "published",
        "image_url": "https://example.com/image.jpg"
      },
      "relationships": {
        "organizer": {
          "data": { "id": "1", "type": "users" }
        }
      }
    }
  ],
  "meta": {
    "total": 1,
    "page": 1,
    "per_page": 10
  }
}
```

### チケット購入

```
POST /api/v1/ticket_types/1/purchase
```

#### リクエスト例
```json
{
  "quantity": 1,
  "attendee": {
    "name": "山田太郎",
    "email": "taro@example.com",
    "phone": "090-1234-5678"
  },
  "payment": {
    "method": "stripe",
    "token": "tok_visa"
  }
}
```

#### レスポンス例
```json
{
  "data": {
    "id": "123",
    "type": "tickets",
    "attributes": {
      "code": "EVNT-ABC123",
      "qr_url": "https://api.eventa.app/tickets/123/qr",
      "status": "confirmed",
      "purchase_at": "2025-04-30T09:15:00Z",
      "attendee_name": "山田太郎",
      "price_paid_cents": 100000
    },
    "relationships": {
      "ticket_type": {
        "data": { "id": "1", "type": "ticket_types" }
      },
      "event": {
        "data": { "id": "1", "type": "events" }
      }
    }
  }
}
```

## エラーレスポンス

```json
{
  "status": 422,
  "error": "validation_error",
  "message": "入力内容に誤りがあります。",
  "details": [
    {
      "field": "attendee.email",
      "code": "invalid_format",
      "message": "有効なメールアドレスを入力してください。"
    }
  ]
}
```

## ステータスコード

| コード | 説明 |
|-------|------|
| 200 | 成功 |
| 201 | リソース作成成功 |
| 400 | リクエスト不正 |
| 401 | 認証エラー |
| 403 | 権限不足 |
| 404 | リソース不存在 |
| 422 | バリデーションエラー |
| 429 | レート制限超過 |
| 500 | サーバーエラー | 