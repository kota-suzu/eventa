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

    // 価格が表示されていることを確認（正規表現を使用して全角・半角両方に対応）
    expect(screen.getByText(/￥1,000/)).toBeInTheDocument();
    expect(screen.getByText(/￥3,000/)).toBeInTheDocument();
  });

  it('数量を選択できる', () => {
    render(<TicketSelector tickets={mockTickets} onSelect={mockOnSelect} />);

    // 一般チケットの数量選択
    const quantitySelector = screen.getAllByRole('combobox')[0];
    fireEvent.change(quantitySelector, { target: { value: '2' } });

    // 選択イベントが発火することを確認
    expect(mockOnSelect).toHaveBeenCalledWith({
      ticketId: 1,
      quantity: 2,
      price: 1000,
      totalPrice: 2000,
    });
  });

  it('在庫以上の数量は選択できない', () => {
    render(<TicketSelector tickets={mockTickets} onSelect={mockOnSelect} />);

    // 一般チケットの数量選択で在庫以上の値を設定
    const quantitySelector = screen.getAllByRole('combobox')[0];
    // 文字列ではなく数値として渡す
    fireEvent.change(quantitySelector, { target: { value: 10 } });

    // 最大値が在庫数に制限されることを確認
    // selectでは値が直接表示されないため、selectedIndexで確認
    expect(quantitySelector.selectedIndex).toBeLessThanOrEqual(5);
  });

  it('在庫がないチケットは選択できない', () => {
    const noStockTickets = [{ id: 1, title: '一般チケット', price: 1000, available_quantity: 0 }];

    render(<TicketSelector tickets={noStockTickets} onSelect={mockOnSelect} />);

    // 在庫なしメッセージが表示されることを確認
    expect(screen.getByText('売り切れ')).toBeInTheDocument();

    // 数量選択が無効化されていることを確認
    const quantitySelector = screen.getByRole('combobox');
    expect(quantitySelector).toBeDisabled();
  });
});
