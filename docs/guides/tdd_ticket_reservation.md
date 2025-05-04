# イベントチケット予約システム TDDテスト計画書

**ドキュメントバージョン**: 1.0  
**最終更新日**: 2025-05-15  
**機能ID**: TICKET-RESERVE-001  
**テスト担当**: 開発チーム

## 1. テスト駆動開発（TDD）アプローチ

このドキュメントは、EventaプラットフォームのイベントチケットのTDD（テスト駆動開発）アプローチを定義します。TDDサイクルに従い、「テスト作成 → 実装 → リファクタリング」のプロセスを繰り返し適用します。

### 1.1 TDDの3原則

1. **Red**: 最初に失敗するテストを書く
2. **Green**: 最小限の実装でテストを通す
3. **Refactor**: テストを通したまま、コードを改善する

### 1.2 テスト対象コンポーネント

- バックエンド
  - チケットモデル
  - 予約コントローラー
  - 在庫管理サービス
  - 決済連携処理

- フロントエンド
  - チケット選択コンポーネント
  - 予約フォーム
  - 予約確認ページ
  - 予約完了画面

## 2. バックエンドTDDシナリオ

### 2.1 Ticketモデルのテスト

```ruby
# spec/models/ticket_spec.rb

require "rails_helper"

RSpec.describe Ticket, type: :model do
  describe "バリデーション" do
    it "有効なチケットは作成できる" do
      ticket = build(:ticket)
      expect(ticket).to be_valid
    end

    it "タイトルなしでは無効" do
      ticket = build(:ticket, title: nil)
      expect(ticket).not_to be_valid
      expect(ticket.errors[:title]).to include("を入力してください")
    end

    it "イベントIDなしでは無効" do
      ticket = build(:ticket, event_id: nil)
      expect(ticket).not_to be_valid
      expect(ticket.errors[:event_id]).to include("を入力してください")
    end

    it "価格は0以上でなければならない" do
      ticket = build(:ticket, price: -100)
      expect(ticket).not_to be_valid
      expect(ticket.errors[:price]).to include("は0以上の値にしてください")
    end

    it "在庫数は1以上でなければならない" do
      ticket = build(:ticket, quantity: 0)
      expect(ticket).not_to be_valid
      expect(ticket.errors[:quantity]).to include("は1以上の値にしてください")
    end
  end

  describe "在庫管理" do
    let(:ticket) { create(:ticket, quantity: 5) }

    it "予約で在庫を減らせる" do
      expect {
        ticket.reserve(2)
      }.to change { ticket.available_quantity }.by(-2)
    end

    it "在庫以上の予約はエラーとなる" do
      expect {
        ticket.reserve(6)
      }.to raise_error(Ticket::InsufficientQuantityError)
    end

    it "同時予約で競合が発生しないこと" do
      # 悲観的ロックのテスト
      threads = []
      3.times do
        threads << Thread.new do
          Ticket.transaction do
            t = Ticket.lock.find(ticket.id)
            t.reserve(1)
          end
        end
      end
      threads.each(&:join)
      
      # 全スレッド完了後に在庫を確認
      expect(ticket.reload.available_quantity).to eq(2)
    end
  end
end
```

### 2.2 TicketReservationsコントローラのテスト

```ruby
# spec/requests/ticket_reservations_spec.rb

require "rails_helper"

RSpec.describe "TicketReservations", type: :request do
  let(:user) { create(:user) }
  let(:event) { create(:event) }
  let!(:ticket) { create(:ticket, event: event, quantity: 10, price: 1000) }
  let(:valid_params) do
    {
      ticket_id: ticket.id,
      quantity: 2,
      payment_method: "credit_card",
      card_token: "tok_visa"
    }
  end

  describe "POST /api/v1/ticket_reservations" do
    context "認証済みユーザー" do
      before do
        # 認証ヘッダーを設定
        post "/api/v1/login", params: { email: user.email, password: "password" }
        @token = JSON.parse(response.body)["token"]
      end

      it "チケット予約が成功する" do
        expect {
          post "/api/v1/ticket_reservations", 
               params: valid_params, 
               headers: { "Authorization" => "Bearer #{@token}" }
        }.to change(Reservation, :count).by(1)
        
        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["reservation"]["status"]).to eq("pending")
        expect(json["reservation"]["total_price"]).to eq(2000) # 1000円 x 2枚
      end

      it "在庫不足の場合は予約が失敗する" do
        params = valid_params.merge(quantity: 11) # 在庫は10枚
        
        post "/api/v1/ticket_reservations", 
             params: params, 
             headers: { "Authorization" => "Bearer #{@token}" }
        
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["error"]).to include("在庫不足")
      end

      it "支払い方法が不正な場合は予約が失敗する" do
        params = valid_params.merge(payment_method: "invalid_method")
        
        post "/api/v1/ticket_reservations", 
             params: params, 
             headers: { "Authorization" => "Bearer #{@token}" }
        
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["error"]).to include("支払い方法")
      end
    end

    context "未認証ユーザー" do
      it "認証エラーを返す" do
        post "/api/v1/ticket_reservations", params: valid_params
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
```

### 2.3 決済サービスのテスト

```ruby
# spec/services/payment_service_spec.rb

require "rails_helper"

RSpec.describe PaymentService do
  let(:user) { create(:user) }
  let(:reservation) { create(:reservation, user: user, total_price: 2000) }
  
  describe "#process" do
    context "クレジットカード決済" do
      let(:payment_params) do
        {
          method: "credit_card",
          token: "tok_visa",
          amount: 2000
        }
      end
      
      it "決済が成功する" do
        # Stripeモックを設定
        charge = double("Stripe::Charge")
        allow(Stripe::Charge).to receive(:create).and_return(charge)
        allow(charge).to receive(:id).and_return("ch_123456")
        allow(charge).to receive(:status).and_return("succeeded")
        
        service = PaymentService.new(reservation, payment_params)
        result = service.process
        
        expect(result.success?).to be true
        expect(result.transaction_id).to eq("ch_123456")
        expect(reservation.reload.status).to eq("confirmed")
      end
      
      it "決済が失敗する場合" do
        # Stripeエラーをモック
        allow(Stripe::Charge).to receive(:create).and_raise(Stripe::CardError.new("カードが拒否されました", nil, nil))
        
        service = PaymentService.new(reservation, payment_params)
        result = service.process
        
        expect(result.success?).to be false
        expect(result.error_message).to include("カードが拒否されました")
        expect(reservation.reload.status).to eq("payment_failed")
      end
    end
  end
end
```

## 3. フロントエンドTDDシナリオ

### 3.1 チケット選択コンポーネントのテスト

```javascript
// tests/components/TicketSelector.test.js

import { render, screen, fireEvent } from '@testing-library/react';
import TicketSelector from '../../components/TicketSelector';

const mockTickets = [
  { id: 1, title: '一般チケット', price: 1000, available_quantity: 5 },
  { id: 2, title: 'VIPチケット', price: 3000, available_quantity: 2 },
];

describe('TicketSelector', () => {
  const mockOnSelect = jest.fn();

  beforeEach(() => {
    // モックのリセット
    mockOnSelect.mockClear();
  });

  it('チケットリストを表示する', () => {
    render(<TicketSelector tickets={mockTickets} onSelect={mockOnSelect} />);
    
    // 全てのチケットがリストに表示されていることを確認
    expect(screen.getByText('一般チケット')).toBeInTheDocument();
    expect(screen.getByText('VIPチケット')).toBeInTheDocument();
    
    // 価格が表示されていることを確認
    expect(screen.getByText('¥1,000')).toBeInTheDocument();
    expect(screen.getByText('¥3,000')).toBeInTheDocument();
  });
  
  it('数量を選択できる', () => {
    render(<TicketSelector tickets={mockTickets} onSelect={mockOnSelect} />);
    
    // 一般チケットの数量選択
    const quantitySelector = screen.getAllByRole('spinbutton')[0];
    fireEvent.change(quantitySelector, { target: { value: '2' } });
    
    // 選択イベントが発火することを確認
    expect(mockOnSelect).toHaveBeenCalledWith({ 
      ticketId: 1, 
      quantity: 2,
      price: 1000,
      totalPrice: 2000 
    });
  });
  
  it('在庫以上の数量は選択できない', () => {
    render(<TicketSelector tickets={mockTickets} onSelect={mockOnSelect} />);
    
    // 一般チケットの数量選択で在庫以上の値を設定
    const quantitySelector = screen.getAllByRole('spinbutton')[0];
    fireEvent.change(quantitySelector, { target: { value: '10' } });
    
    // 最大値が在庫数に制限されることを確認
    expect(quantitySelector.value).toBe('5');
  });
  
  it('在庫がないチケットは選択できない', () => {
    const noStockTickets = [
      { id: 1, title: '一般チケット', price: 1000, available_quantity: 0 },
    ];
    
    render(<TicketSelector tickets={noStockTickets} onSelect={mockOnSelect} />);
    
    // 在庫なしメッセージが表示されることを確認
    expect(screen.getByText('売り切れ')).toBeInTheDocument();
    
    // 数量選択が無効化されていることを確認
    const quantitySelector = screen.getByRole('spinbutton');
    expect(quantitySelector).toBeDisabled();
  });
});
```

### 3.2 予約フォームのテスト

```javascript
// tests/components/ReservationForm.test.js

import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { AuthContext } from '../../contexts/AuthContext';
import ReservationForm from '../../components/ReservationForm';
import * as api from '../../utils/api';

// APIコールのモック
jest.mock('../../utils/api');

describe('ReservationForm', () => {
  const mockTickets = [
    { id: 1, title: '一般チケット', price: 1000, available_quantity: 5 },
  ];
  
  const mockUser = {
    id: 1,
    name: 'テストユーザー',
    email: 'test@example.com'
  };
  
  const mockAuthContext = {
    user: mockUser,
    isAuthenticated: true
  };
  
  beforeEach(() => {
    // モックのリセット
    jest.clearAllMocks();
  });
  
  it('フォームが正しく表示される', () => {
    render(
      <AuthContext.Provider value={mockAuthContext}>
        <ReservationForm eventId={1} tickets={mockTickets} />
      </AuthContext.Provider>
    );
    
    // チケットセレクタが表示されていることを確認
    expect(screen.getByText('一般チケット')).toBeInTheDocument();
    
    // 支払い方法選択が表示されていることを確認
    expect(screen.getByText('支払い方法')).toBeInTheDocument();
    expect(screen.getByLabelText('クレジットカード')).toBeInTheDocument();
    
    // ユーザー情報が自動入力されていることを確認
    expect(screen.getByDisplayValue('テストユーザー')).toBeInTheDocument();
    expect(screen.getByDisplayValue('test@example.com')).toBeInTheDocument();
  });
  
  it('予約が成功する', async () => {
    // 予約APIのモック成功レスポンス
    api.createReservation.mockResolvedValue({
      id: 123,
      status: 'pending',
      total_price: 2000,
      payment_url: 'https://example.com/pay'
    });
    
    render(
      <AuthContext.Provider value={mockAuthContext}>
        <ReservationForm eventId={1} tickets={mockTickets} />
      </AuthContext.Provider>
    );
    
    // チケット選択
    const quantitySelector = screen.getByRole('spinbutton');
    fireEvent.change(quantitySelector, { target: { value: '2' } });
    
    // クレジットカード選択
    const creditCardRadio = screen.getByLabelText('クレジットカード');
    fireEvent.click(creditCardRadio);
    
    // フォーム送信
    const submitButton = screen.getByRole('button', { name: '予約する' });
    fireEvent.click(submitButton);
    
    // 送信中表示を確認
    expect(screen.getByText('処理中...')).toBeInTheDocument();
    
    // 成功後の状態を確認
    await waitFor(() => {
      expect(api.createReservation).toHaveBeenCalledWith({
        event_id: 1,
        ticket_id: 1,
        quantity: 2,
        payment_method: 'credit_card'
      });
      expect(window.location.href).toBe('https://example.com/pay');
    });
  });
  
  it('予約が失敗する', async () => {
    // 予約APIのモック失敗レスポンス
    api.createReservation.mockRejectedValue({
      response: {
        data: {
          error: '在庫が不足しています'
        }
      }
    });
    
    render(
      <AuthContext.Provider value={mockAuthContext}>
        <ReservationForm eventId={1} tickets={mockTickets} />
      </AuthContext.Provider>
    );
    
    // チケット選択と送信
    const quantitySelector = screen.getByRole('spinbutton');
    fireEvent.change(quantitySelector, { target: { value: '2' } });
    
    const submitButton = screen.getByRole('button', { name: '予約する' });
    fireEvent.click(submitButton);
    
    // エラーメッセージを確認
    await waitFor(() => {
      expect(screen.getByText('在庫が不足しています')).toBeInTheDocument();
    });
  });
});
```

## 4. TDD実施ワークフロー

### 4.1 開発ステップ

1. **テスト作成（Red）**
   - 新機能の要件に基づき、失敗するテストケースを作成する
   - テストを実行し、失敗することを確認する

2. **実装（Green）**
   - テストを通過させるための最小限のコードを実装する
   - テストを再実行し、成功することを確認する

3. **リファクタリング（Refactor）**
   - コードの品質を改善しつつ、テストが成功し続けることを確認する
   - コード重複の排除、命名の改善、パフォーマンス最適化などを行う

### 4.2 開発サイクル例

#### チケット在庫管理機能のTDDサイクル

1. **Red**: 在庫減少のテストを作成
   ```ruby
   it "予約で在庫を減らせる" do
     expect {
       ticket.reserve(2)
     }.to change { ticket.available_quantity }.by(-2)
   end
   ```

2. **Green**: 最小限の実装
   ```ruby
   # app/models/ticket.rb
   def reserve(quantity)
     update!(available_quantity: available_quantity - quantity)
   end
   ```

3. **Red**: 在庫不足チェックのテストを追加
   ```ruby
   it "在庫以上の予約はエラーとなる" do
     expect {
       ticket.reserve(6) # 在庫は5
     }.to raise_error(Ticket::InsufficientQuantityError)
   end
   ```

4. **Green**: エラーハンドリングを追加
   ```ruby
   # app/models/ticket.rb
   class InsufficientQuantityError < StandardError; end
   
   def reserve(quantity)
     if quantity > available_quantity
       raise InsufficientQuantityError, "在庫が不足しています"
     end
     update!(available_quantity: available_quantity - quantity)
   end
   ```

5. **Red**: 同時予約のテストを追加
   ```ruby
   it "同時予約で競合が発生しないこと" do
     # 悲観的ロックのテスト
     threads = []
     3.times do
       threads << Thread.new do
         Ticket.transaction do
           t = Ticket.lock.find(ticket.id)
           t.reserve(1)
         end
       end
     end
     threads.each(&:join)
     
     # 全スレッド完了後に在庫を確認
     expect(ticket.reload.available_quantity).to eq(2)
   end
   ```

6. **Green**: トランザクションと悲観的ロックを追加
   ```ruby
   # app/models/ticket.rb
   def self.reserve_with_lock(id, quantity)
     transaction do
       ticket = lock.find(id)
       ticket.reserve(quantity)
       ticket
     end
   end
   ```

7. **Refactor**: コードの整理と可読性向上
   ```ruby
   # app/models/ticket.rb
   def reserve(quantity)
     check_quantity_available(quantity)
     decrement_stock(quantity)
   end
   
   private
   
   def check_quantity_available(quantity)
     if quantity > available_quantity
       raise InsufficientQuantityError, "在庫が不足しています（残り#{available_quantity}枚）"
     end
   end
   
   def decrement_stock(quantity)
     update!(available_quantity: available_quantity - quantity)
   end
   ```

## 5. 受け入れ基準

1. 全ての単体テストが成功すること（カバレッジ90%以上）
2. 統合テストがすべて成功すること
3. E2Eテストで全ての主要フローが確認できること
4. リファクタリング後もコードの品質が維持されていること
5. 実装が機能仕様書の要件をすべて満たしていること

## 6. まとめ

TDDアプローチを適用することで、以下の利点が期待できます：

1. **機能の正確性**: 要件に基づいたテストから始めることで、実装が確実に仕様を満たす
2. **高品質なコード**: リファクタリングフェーズにより、コードの品質が向上
3. **自己文書化**: テストがコードの使用例や動作仕様書としても機能
4. **安全なリファクタリング**: テストスイートを活用して、安全に実装を改善できる

イベントチケット予約システムのTDD実装におけるポイント：

- 在庫管理における競合状態を避ける同時実行制御
- 決済連携処理のエラーハンドリング
- ユーザーエクスペリエンスを向上させる適切なフィードバック提供 

# app/models/ticket.rb
class Ticket < ApplicationRecord
  belongs_to :event
  has_many :reservations

  validates :title, presence: true
  validates :event_id, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :quantity, numericality: { greater_than_or_equal_to: 1 }

  class InsufficientQuantityError < StandardError; end

  def reserve(quantity)
    check_quantity_available(quantity)
    decrement_stock(quantity)
  end

  def self.reserve_with_lock(id, quantity)
    transaction do
      ticket = lock.find(id)
      ticket.reserve(quantity)
      ticket
    end
  end

  private

  def check_quantity_available(quantity)
    if quantity > available_quantity
      raise InsufficientQuantityError, "在庫が不足しています（残り#{available_quantity}枚）"
    end
  end

  def decrement_stock(quantity)
    update!(available_quantity: available_quantity - quantity)
  end
end 