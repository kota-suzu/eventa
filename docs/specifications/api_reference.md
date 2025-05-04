# eventa API リファレンス (v0.2.0)

**ベース URL**: https://api.eventa.app

本 API は REST/JSON で提供されます。日時はすべて ISO-8601（UTC）です。

## 更新履歴

| バージョン | 日付 | 変更内容 |
|----------|------|---------|
| v0.1.0   | 2025-05-01 | 初期リリース（MVP Alpha） |
| v0.2.0   | 2025-05-04 | 認証システム強化（リフレッシュトークン導入）、JWT セキュリティ強化 |

## 認証と共通仕様

| 項目 | 内容 |
|-----|------|
| 認証方式 | Bearer JWT (Authorization: Bearer \<token\>) |
| JWT属性 | iss（発行者）、aud（対象者）、iat（発行時刻）、exp（有効期限）、jti（一意ID）などの標準クレーム |
| リフレッシュトークン | 30日有効、トークン更新用 |
| ロール | admin, organizer, guest（JWT claim: role） |
| ページネーション | page / per_page クエリ、レスポンスに meta.total 等を含む |
| エラー形式 | status, error, message, details[] |
| レート制限 | 100 req/min/IP (HTTP 429 で通知) |

## エンドポイント一覧

### 認証・ユーザー系 API

| リソース | メソッド | パス | 説明 |
|---------|---------|-----|------|
| Auth | POST | /api/v1/auth/login | ログイン（JWT取得） |
| | POST | /api/v1/auth/register | ユーザー登録 |
| | POST | /api/v1/auth/refresh | JWT更新（リフレッシュトークン使用） |
| | POST | /api/v1/auth/logout | ログアウト（JWT無効化） |
| Users | GET | /api/v1/users/me | 自分のプロフィール取得 |
| | PATCH | /api/v1/users/me | 自分のプロフィール更新 |
| | GET | /api/v1/users/{id} | ユーザー情報取得 |

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

### 認証フロー

#### ユーザー登録
```
POST /api/v1/auth/register
```

##### リクエスト例
```json
{
  "user": {
    "email": "taro@example.com",
    "password": "secure_password123",
    "password_confirmation": "secure_password123",
    "name": "山田太郎",
    "role": "organizer"
  }
}
```

または、以下の形式も受け付けます（authハッシュ内にネスト）:

```json
{
  "auth": {
    "user": {
      "email": "taro@example.com",
      "password": "secure_password123",
      "password_confirmation": "secure_password123",
      "name": "山田太郎",
      "role": "organizer"
    }
  }
}
```

##### レスポンス例（v0.2.0更新）
```json
{
  "user": {
    "id": 1,
    "name": "山田太郎",
    "email": "taro@example.com",
    "bio": null,
    "role": "organizer",
    "created_at": "2025-05-01T08:30:00Z"
  },
  "token": "eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJpc3MiOiJldmVudGEtYXBpLXByb2R1Y3Rpb24iLCJhdWQiOiJldmVudGEtY2xpZW50IiwiaWF0IjoxNjIwMDAwMDAwLCJuYmYiOjE2MjAwMDAwMDAsImp0aSI6ImExYjJjM2Q0LWU1ZjYtZzdoOC1pOWowIiwiZXhwIjoxNjIwMDg2NDAwfQ.signature",
  "refresh_token": "eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJzZXNzaW9uX2lkIjoiMmEzODlkMGNmM2JlM2IzMGJhNTkzOTYyMWM2Zjc4YzEiLCJ0b2tlbl90eXBlIjoicmVmcmVzaCIsImlzcyI6ImV2ZW50YS1hcGktcHJvZHVjdGlvbiIsImF1ZCI6ImV2ZW50YS1jbGllbnQiLCJpYXQiOjE2MjAwMDAwMDAsIm5iZiI6MTYyMDAwMDAwMCwianRpIjoiazFsMm0zbjQtbzVwNi1xN3I4LXM5dDAiLCJleHAiOjE2MjI1OTIwMDB9.signature"
}
```

#### ログイン
```
POST /api/v1/auth/login
```

##### リクエスト例
```json
{
  "email": "taro@example.com",
  "password": "secure_password123"
}
```

または、以下の形式も受け付けます（authハッシュ内にネスト）:

```json
{
  "auth": {
    "email": "taro@example.com",
    "password": "secure_password123",
    "remember": true
  }
}
```

##### レスポンス例（v0.2.0更新）
```json
{
  "user": {
    "id": 1,
    "name": "山田太郎",
    "email": "taro@example.com",
    "bio": null,
    "role": "organizer",
    "created_at": "2025-05-01T08:30:00Z"
  },
  "token": "eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJpc3MiOiJldmVudGEtYXBpLXByb2R1Y3Rpb24iLCJhdWQiOiJldmVudGEtY2xpZW50IiwiaWF0IjoxNjIwMDAwMDAwLCJuYmYiOjE2MjAwMDAwMDAsImp0aSI6ImExYjJjM2Q0LWU1ZjYtZzdoOC1pOWowIiwiZXhwIjoxNjIwMDg2NDAwfQ.signature",
  "refresh_token": "eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJzZXNzaW9uX2lkIjoiMmEzODlkMGNmM2JlM2IzMGJhNTkzOTYyMWM2Zjc4YzEiLCJ0b2tlbl90eXBlIjoicmVmcmVzaCIsImlzcyI6ImV2ZW50YS1hcGktcHJvZHVjdGlvbiIsImF1ZCI6ImV2ZW50YS1jbGllbnQiLCJpYXQiOjE2MjAwMDAwMDAsIm5iZiI6MTYyMDAwMDAwMCwianRpIjoiazFsMm0zbjQtbzVwNi1xN3I4LXM5dDAiLCJleHAiOjE2MjI1OTIwMDB9.signature"
}
```

#### トークン更新（v0.2.0新規追加）
```
POST /api/v1/auth/refresh
```

##### リクエスト例
リフレッシュトークンは以下のいずれかの方法で提供できます：
1. リクエストボディ
```json
{
  "refresh_token": "eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJzZXNzaW9uX2lkIjoiMmEzODlkMGNmM2JlM2IzMGJhNTkzOTYyMWM2Zjc4YzEiLCJ0b2tlbl90eXBlIjoicmVmcmVzaCIsImlzcyI6ImV2ZW50YS1hcGktcHJvZHVjdGlvbiIsImF1ZCI6ImV2ZW50YS1jbGllbnQiLCJpYXQiOjE2MjAwMDAwMDAsIm5iZiI6MTYyMDAwMDAwMCwianRpIjoiazFsMm0zbjQtbzVwNi1xN3I4LXM5dDAiLCJleHAiOjE2MjI1OTIwMDB9.signature"
}
```

2. X-Refresh-Tokenヘッダー
```
X-Refresh-Token: eyJhbGciOiJIUzI1NiJ9...（略）
```

3. HttpOnly Cookie（自動的に送信）
APIはCookieからリフレッシュトークンを自動的に取得します。

##### レスポンス例
```json
{
  "token": "eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJpc3MiOiJldmVudGEtYXBpLXByb2R1Y3Rpb24iLCJhdWQiOiJldmVudGEtY2xpZW50IiwiaWF0IjoxNjIwMDg2NDAwLCJuYmYiOjE2MjAwODY0MDAsImp0aSI6ImIxYzJkM2U0LWY1ZzYtaDdpOC1qOWswIiwiZXhwIjoxNjIwMTcyODAwfQ.new-signature",
  "user": {
    "id": 1,
    "name": "山田太郎",
    "email": "taro@example.com",
    "bio": null,
    "role": "organizer",
    "created_at": "2025-05-01T08:30:00Z"
  }
}
```

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

### イベント作成

```
POST /api/v1/events
Authorization: Bearer <token>
```

#### リクエスト例
```json
{
  "event": {
    "name": "Tech Conference 2025",
    "description": "最新技術動向の紹介と業界トップのスピーカーによるセッション",
    "start_at": "2025-06-01T10:00:00Z",
    "end_at": "2025-06-01T18:00:00Z",
    "venue": "東京カンファレンスセンター",
    "venue_address": "東京都千代田区丸の内1-1-1",
    "venue_map_url": "https://maps.example.com/venue123",
    "capacity": 300,
    "image_url": "https://example.com/image.jpg",
    "website_url": "https://conference.example.com",
    "status": "draft",
    "is_online": false,
    "online_access_info": "",
    "tags": ["tech", "ai", "programming"]
  }
}
```

#### レスポンス例
```json
{
  "data": {
    "id": "1",
    "type": "events",
    "attributes": {
      "name": "Tech Conference 2025",
      "description": "最新技術動向の紹介と業界トップのスピーカーによるセッション",
      "start_at": "2025-06-01T10:00:00Z",
      "end_at": "2025-06-01T18:00:00Z",
      "venue": "東京カンファレンスセンター",
      "venue_address": "東京都千代田区丸の内1-1-1",
      "venue_map_url": "https://maps.example.com/venue123",
      "capacity": 300,
      "status": "draft",
      "is_online": false,
      "online_access_info": "",
      "image_url": "https://example.com/image.jpg",
      "website_url": "https://conference.example.com",
      "tags": ["tech", "ai", "programming"],
      "created_at": "2025-05-01T10:30:00Z",
      "updated_at": "2025-05-01T10:30:00Z"
    },
    "relationships": {
      "organizer": {
        "data": { "id": "1", "type": "users" }
      },
      "ticket_types": {
        "data": []
      }
    }
  }
}
```

### イベント更新

```
PATCH /api/v1/events/1
Authorization: Bearer <token>
```

#### リクエスト例
```json
{
  "event": {
    "status": "published",
    "description": "最新技術動向の紹介と業界トップのスピーカーによるセッション。ネットワーキングランチ付き。"
  }
}
```

#### レスポンス例
```json
{
  "data": {
    "id": "1",
    "type": "events",
    "attributes": {
      "name": "Tech Conference 2025",
      "description": "最新技術動向の紹介と業界トップのスピーカーによるセッション。ネットワーキングランチ付き。",
      "start_at": "2025-06-01T10:00:00Z",
      "end_at": "2025-06-01T18:00:00Z",
      "venue": "東京カンファレンスセンター",
      "venue_address": "東京都千代田区丸の内1-1-1",
      "venue_map_url": "https://maps.example.com/venue123",
      "capacity": 300,
      "status": "published",
      "is_online": false,
      "online_access_info": "",
      "image_url": "https://example.com/image.jpg",
      "website_url": "https://conference.example.com",
      "tags": ["tech", "ai", "programming"],
      "created_at": "2025-05-01T10:30:00Z",
      "updated_at": "2025-05-01T11:15:00Z"
    },
    "relationships": {
      "organizer": {
        "data": { "id": "1", "type": "users" }
      },
      "ticket_types": {
        "data": []
      }
    }
  }
}
```

### チケットタイプ作成

```
POST /api/v1/events/1/ticket_types
Authorization: Bearer <token>
```

#### リクエスト例
```json
{
  "ticket_type": {
    "name": "一般チケット",
    "description": "カンファレンス全日程へのアクセス権",
    "price_cents": 100000,
    "currency": "JPY",
    "quantity": 200,
    "sale_start_at": "2025-05-15T00:00:00Z",
    "sale_end_at": "2025-05-31T23:59:59Z",
    "status": "active",
    "max_per_order": 5
  }
}
```

#### レスポンス例
```json
{
  "data": {
    "id": "1",
    "type": "ticket_types",
    "attributes": {
      "name": "一般チケット",
      "description": "カンファレンス全日程へのアクセス権",
      "price_cents": 100000,
      "currency": "JPY",
      "quantity": 200,
      "quantity_sold": 0,
      "quantity_available": 200,
      "sale_start_at": "2025-05-15T00:00:00Z",
      "sale_end_at": "2025-05-31T23:59:59Z",
      "status": "active",
      "max_per_order": 5,
      "created_at": "2025-05-01T14:30:00Z",
      "updated_at": "2025-05-01T14:30:00Z"
    },
    "relationships": {
      "event": {
        "data": { "id": "1", "type": "events" }
      }
    }
  }
}
```

### チケットタイプ一覧取得

```
GET /api/v1/events/1/ticket_types
```

#### レスポンス例
```json
{
  "data": [
    {
      "id": "1",
      "type": "ticket_types",
      "attributes": {
        "name": "一般チケット",
        "description": "カンファレンス全日程へのアクセス権",
        "price_cents": 100000,
        "currency": "JPY",
        "quantity": 200,
        "quantity_sold": 5,
        "quantity_available": 195,
        "sale_start_at": "2025-05-15T00:00:00Z",
        "sale_end_at": "2025-05-31T23:59:59Z",
        "status": "active"
      },
      "relationships": {
        "event": {
          "data": { "id": "1", "type": "events" }
        }
      }
    },
    {
      "id": "2",
      "type": "ticket_types",
      "attributes": {
        "name": "VIPチケット",
        "description": "全日程アクセス＋ネットワーキングディナー",
        "price_cents": 200000,
        "currency": "JPY",
        "quantity": 50,
        "quantity_sold": 2,
        "quantity_available": 48,
        "sale_start_at": "2025-05-15T00:00:00Z",
        "sale_end_at": "2025-05-31T23:59:59Z",
        "status": "active"
      },
      "relationships": {
        "event": {
          "data": { "id": "1", "type": "events" }
        }
      }
    }
  ],
  "meta": {
    "total": 2
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

### チケットキャンセル

```
PATCH /api/v1/tickets/123/cancel
Authorization: Bearer <token>
```

#### リクエスト例
```json
{
  "reason": "日程の都合",
  "refund_requested": true
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
      "status": "cancelled",
      "purchase_at": "2025-04-30T09:15:00Z",
      "cancelled_at": "2025-05-01T15:30:00Z",
      "attendee_name": "山田太郎",
      "price_paid_cents": 100000,
      "refund_status": "pending",
      "refund_amount_cents": 100000
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

### チェックイン処理

```
PUT /api/v1/tickets/123/check_in
Authorization: Bearer <token>
```

#### リクエスト例
```json
{
  "location": "エントランスゲート1",
  "operator_note": "本人確認済み"
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
      "status": "checked_in",
      "purchase_at": "2025-04-30T09:15:00Z",
      "check_in_at": "2025-06-01T09:45:00Z",
      "attendee_name": "山田太郎"
    },
    "relationships": {
      "ticket_type": {
        "data": { "id": "1", "type": "ticket_types" }
      },
      "event": {
        "data": { "id": "1", "type": "events" }
      },
      "check_in_record": {
        "data": { "id": "45", "type": "check_in_records" }
      }
    }
  }
}
```

### QRコード検証（オフライン用）

```
POST /api/v1/tickets/validate
Authorization: Bearer <token>
```

#### リクエスト例
```json
{
  "ticket_code": "EVNT-ABC123"
}
```

#### レスポンス例
```json
{
  "valid": true,
  "ticket": {
    "id": "123",
    "code": "EVNT-ABC123",
    "status": "confirmed",
    "attendee_name": "山田太郎",
    "event_name": "Tech Conference 2025",
    "ticket_type_name": "一般チケット"
  },
  "validation_timestamp": "2025-06-01T09:30:00Z"
}
```

## エラーレスポンス

### 認証エラー
```
HTTP/1.1 401 Unauthorized
```
```json
{
  "error": "メールアドレスまたはパスワードが無効です",
  "status": 401
}
```

### リフレッシュトークンエラー
```
HTTP/1.1 401 Unauthorized
```
```json
{
  "error": "無効なリフレッシュトークン",
  "status": 401
}
```

### 権限エラー
```
HTTP/1.1 403 Forbidden
```
```json
{
  "error": "このリソースにアクセスする権限がありません",
  "status": 403
}
```

### バリデーションエラー
```
HTTP/1.1 422 Unprocessable Entity
```
```json
{
  "errors": [
    "メールアドレスは既に使用されています",
    "パスワードは8文字以上である必要があります"
  ],
  "status": 422
}
```

## JWTトークン形式と検証

### アクセストークン（JWT）の構造

```javascript
// ヘッダー
{
  "alg": "HS256",
  "typ": "JWT"
}

// ペイロード
{
  "user_id": 123,
  "iss": "eventa-api-production",  // 発行者
  "aud": "eventa-client",          // 対象者
  "iat": 1620000000,               // 発行時刻
  "nbf": 1620000000,               // 有効開始時刻
  "jti": "a1b2c3d4-e5f6-g7h8-i9j0", // トークン一意ID
  "exp": 1620086400                // 有効期限（24時間）
}

// 署名（HMAC SHA-256）
HMACSHA256(
  base64UrlEncode(header) + "." + base64UrlEncode(payload),
  secret
)
```

### リフレッシュトークンの構造

```javascript
// ヘッダー
{
  "alg": "HS256",
  "typ": "JWT"
}

// ペイロード
{
  "user_id": 123,
  "session_id": "2a389d0cf3be3b30ba5939621c6f78c1", // セッションID
  "token_type": "refresh",         // トークン種別
  "iss": "eventa-api-production",  // 発行者
  "aud": "eventa-client",          // 対象者
  "iat": 1620000000,               // 発行時刻
  "nbf": 1620000000,               // 有効開始時刻
  "jti": "k1l2m3n4-o5p6-q7r8-s9t0", // トークン一意ID
  "exp": 1622592000                // 有効期限（30日）
}

// 署名（HMAC SHA-256）
HMACSHA256(
  base64UrlEncode(header) + "." + base64UrlEncode(payload),
  secret
)
```

## クライアント実装ガイド

### トークン管理

1. **アクセストークン（JWT）** - 有効期限：24時間
   - 全てのAPI呼び出しに使用
   - 期限切れ時はリフレッシュトークンで更新

2. **リフレッシュトークン** - 有効期限：30日
   - アクセストークン更新にのみ使用
   - HttpOnly Cookie として保存される（セキュリティ向上）
   - logout時に無効化

### 推奨実装パターン

1. **初期認証**
   - `/api/v1/auth/login`でログイン
   - 返却された`token`と`refresh_token`を保存

2. **API呼び出し**
   - `Authorization: Bearer {token}`ヘッダーを付与

3. **トークン期限切れ処理**
   - 401エラー時、リフレッシュトークンを使用して更新試行
   - `/api/v1/auth/refresh`を呼び出し
   - 新しいアクセストークンを取得して再試行
   - リフレッシュに失敗した場合、ログイン画面にリダイレクト

## SDKとサンプルコード

### JavaScript (Node.js)

```javascript
const axios = require('axios');

class EventaClient {
  constructor(apiToken) {
    this.axios = axios.create({
      baseURL: 'https://api.eventa.app',
      headers: {
        'Authorization': `Bearer ${apiToken}`,
        'Content-Type': 'application/json'
      }
    });
  }

  async getEvents(page = 1, perPage = 10) {
    try {
      const response = await this.axios.get(`/api/v1/events?page=${page}&per_page=${perPage}`);
      return response.data;
    } catch (error) {
      this.handleError(error);
    }
  }

  async createEvent(eventData) {
    try {
      const response = await this.axios.post('/api/v1/events', { event: eventData });
      return response.data;
    } catch (error) {
      this.handleError(error);
    }
  }

  async purchaseTicket(ticketTypeId, quantity, attendee, payment) {
    try {
      const response = await this.axios.post(`/api/v1/ticket_types/${ticketTypeId}/purchase`, {
        quantity,
        attendee,
        payment
      });
      return response.data;
    } catch (error) {
      this.handleError(error);
    }
  }

  handleError(error) {
    if (error.response) {
      console.error('API Error:', error.response.data);
      throw error.response.data;
    } else {
      console.error('Network Error:', error.message);
      throw new Error('Network error');
    }
  }
}

// 使用例
async function main() {
  const client = new EventaClient('your-jwt-token');
  
  try {
    // イベント一覧取得
    const events = await client.getEvents();
    console.log('Events:', events);

    // チケット購入
    const ticket = await client.purchaseTicket('1', 1, {
      name: '山田太郎',
      email: 'taro@example.com',
      phone: '090-1234-5678'
    }, {
      method: 'stripe',
      token: 'tok_visa'
    });
    console.log('Purchased Ticket:', ticket);
  } catch (error) {
    console.error('Error:', error);
  }
}

main();
```

### Ruby

```ruby
require 'httparty'
require 'json'

class EventaClient
  include HTTParty
  base_uri 'https://api.eventa.app'
  
  def initialize(api_token)
    @options = {
      headers: {
        'Authorization' => "Bearer #{api_token}",
        'Content-Type' => 'application/json'
      }
    }
  end
  
  def get_events(page: 1, per_page: 10)
    response = self.class.get(
      "/api/v1/events?page=#{page}&per_page=#{per_page}", 
      @options
    )
    handle_response(response)
  end
  
  def create_event(event_data)
    response = self.class.post(
      '/api/v1/events', 
      @options.merge(body: { event: event_data }.to_json)
    )
    handle_response(response)
  end
  
  def purchase_ticket(ticket_type_id, quantity, attendee, payment)
    response = self.class.post(
      "/api/v1/ticket_types/#{ticket_type_id}/purchase",
      @options.merge(body: {
        quantity: quantity,
        attendee: attendee,
        payment: payment
      }.to_json)
    )
    handle_response(response)
  end
  
  private
  
  def handle_response(response)
    if response.success?
      JSON.parse(response.body)
    else
      raise "API Error: #{response.code} - #{response.body}"
    end
  end
end

# 使用例
client = EventaClient.new('your-jwt-token')

# イベント一覧取得
events = client.get_events
puts "イベント数: #{events['meta']['total']}"

# チケット購入
ticket = client.purchase_ticket('1', 1, {
  name: '山田太郎',
  email: 'taro@example.com',
  phone: '090-1234-5678'
}, {
  method: 'stripe',
  token: 'tok_visa'
})
puts "チケットコード: #{ticket['data']['attributes']['code']}"
```

## APIのバージョニング

本APIはセマンティックバージョニングに従います。バージョン間の互換性は以下の通りです：

- **メジャーバージョン (x.0.0)**: 互換性のない変更
- **マイナーバージョン (0.x.0)**: 後方互換性のある機能追加
- **パッチバージョン (0.0.x)**: 後方互換性のあるバグ修正

v1系APIは2025年末まで安定的にサポートされる予定です。将来的な変更に備えて、APIクライアントは`Accept`ヘッダーにAPIバージョンを含めることが推奨されます:

```
Accept: application/json; version=1
```

## サポート

技術的な質問やAPI利用に関するサポートは以下の方法で受け付けています：

- 開発者フォーラム: [https://developer.eventa.app/forum](https://developer.eventa.app/forum)
- サポートメール: api-support@eventa.app
- APIステータスページ: [https://status.eventa.app](https://status.eventa.app)