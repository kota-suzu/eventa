# eventa API リファレンス (v0.1.0)

**ベース URL**: https://api.eventa.app

本 API は REST/JSON で提供されます。日時はすべて ISO-8601（UTC）です。

## 更新履歴

| バージョン | 日付 | 変更内容 |
|----------|------|---------|
| v0.1.0   | 2025-05-01 | 初期リリース（MVP Alpha） |

## 認証と共通仕様

| 項目 | 内容 |
|-----|------|
| 認証方式 | Bearer JWT (Authorization: Bearer \<token\>) |
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
| | POST | /api/v1/auth/refresh | JWT更新 |
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

##### レスポンス例
```json
{
  "data": {
    "id": "1",
    "type": "users",
    "attributes": {
      "email": "taro@example.com",
      "name": "山田太郎",
      "role": "organizer",
      "created_at": "2025-05-01T08:30:00Z"
    }
  },
  "meta": {
    "token": "eyJhbGciOiJIUzI1NiJ9...",
    "expires_at": "2025-05-02T08:30:00Z"
  }
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

##### レスポンス例
```json
{
  "data": {
    "id": "1",
    "type": "users",
    "attributes": {
      "email": "taro@example.com",
      "name": "山田太郎",
      "role": "organizer"
    }
  },
  "meta": {
    "token": "eyJhbGciOiJIUzI1NiJ9...",
    "expires_at": "2025-05-02T09:15:00Z",
    "refresh_token": "rt_1a2b3c4d..."
  }
}
```

#### トークン更新
```
POST /api/v1/auth/refresh
```

##### リクエスト例
```json
{
  "refresh_token": "rt_1a2b3c4d..."
}
```

##### レスポンス例
```json
{
  "meta": {
    "token": "eyJhbGciOiJIUzI1NiJ9...[new-token]",
    "expires_at": "2025-05-03T09:15:00Z",
    "refresh_token": "rt_5e6f7g8h..."
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

## エラーコードと対処法

APIがエラーを返す場合、標準的なHTTPステータスコードと共に、詳細なエラーコードとメッセージが返されます。

| エラーコード | 説明 | 対処法 |
|------------|------|-------|
| `validation_error` | 入力値のバリデーションエラー | detailsフィールドを参照して入力値を修正 |
| `authentication_required` | 認証が必要 | 有効なトークンを取得して再リクエスト |
| `token_expired` | トークンの期限切れ | リフレッシュトークンを使用して新しいトークンを取得 |
| `permission_denied` | 権限不足 | 必要な権限を持つユーザーで操作 |
| `resource_not_found` | リソースが存在しない | リソースIDを確認 |
| `rate_limit_exceeded` | レート制限超過 | リクエスト頻度を下げる |
| `insufficient_funds` | 支払い残高不足 | 別の支払い方法を試す |
| `event_full` | イベント定員超過 | 他のイベントを探す |
| `ticket_sold_out` | チケット売り切れ | 他のチケットタイプを検討 |
| `already_checked_in` | すでにチェックイン済み | 同一チケットの重複使用は不可 |
| `invalid_ticket_code` | 無効なチケットコード | コードを確認するか正規の購入経路を利用 |
| `internal_server_error` | 内部サーバーエラー | しばらく待ってから再試行、問題が続く場合はサポートに連絡 |

## API利用のベストプラクティス

### レート制限の回避
- クライアント側でのキャッシュを活用する
- 必要な情報のみをリクエストする
- バッチ処理の利用を検討する

### エラーハンドリング
- 全てのエラーに対応する処理を実装する
- 429エラーの場合はバックオフアルゴリズムを実装する
- HTTP 5xxエラーではリトライロジックを実装する

### セキュリティ
- JWTはクライアントサイドで安全に保管する
- 不要になったトークンは明示的にログアウト（無効化）する
- センシティブな情報はSSL/TLS経由でのみ送信する

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