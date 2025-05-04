import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { AuthContext } from '../../contexts/AuthContext';
import ReservationForm from '../../components/ReservationForm';
import * as api from '../../utils/api';
import { useRouter } from 'next/router';

// APIコールのモック
jest.mock('../../utils/api');
// Next.jsのルーターをモック
jest.mock('next/router', () => ({
  useRouter: jest.fn(),
}));

describe('ReservationForm', () => {
  const mockTickets = [{ id: 1, title: '一般チケット', price: 1000, available_quantity: 5 }];

  const mockUser = {
    id: 1,
    name: 'テストユーザー',
    email: 'test@example.com',
  };

  const mockAuthContext = {
    user: mockUser,
    isAuthenticated: true,
  };

  const mockRouter = {
    push: jest.fn(),
  };

  beforeEach(() => {
    // モックのリセット
    jest.clearAllMocks();
    useRouter.mockReturnValue(mockRouter);
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
      payment_url: 'https://example.com/pay',
    });

    render(
      <AuthContext.Provider value={mockAuthContext}>
        <ReservationForm eventId={1} tickets={mockTickets} />
      </AuthContext.Provider>
    );

    // チケット選択
    const quantitySelector = screen.getByRole('combobox');
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
        payment_method: 'credit_card',
      });
      // location.href ではなく router.push が呼ばれることを確認
      expect(mockRouter.push).toHaveBeenCalledWith('https://example.com/pay');
    });
  });

  it('予約が失敗する', async () => {
    // 予約APIのモック失敗レスポンス
    api.createReservation.mockRejectedValue({
      response: {
        data: {
          error: '在庫が不足しています',
        },
      },
    });

    render(
      <AuthContext.Provider value={mockAuthContext}>
        <ReservationForm eventId={1} tickets={mockTickets} />
      </AuthContext.Provider>
    );

    // チケット選択と送信
    const quantitySelector = screen.getByRole('combobox');
    fireEvent.change(quantitySelector, { target: { value: '2' } });

    const submitButton = screen.getByRole('button', { name: '予約する' });
    fireEvent.click(submitButton);

    // エラーメッセージを確認
    await waitFor(() => {
      expect(screen.getByText('在庫が不足しています')).toBeInTheDocument();
    });
  });
});
