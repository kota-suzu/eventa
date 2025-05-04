import React from 'react';
import { render, screen } from '@testing-library/react';
import Events from '../../pages/events';
import { AuthProvider } from '../../contexts/AuthContext';

// モックデータ
const mockEvents = [
  {
    id: 1,
    title: 'テクノロジーカンファレンス',
    date: '2025-06-15',
    type: 'ビジネス',
    description: '最新技術動向について学ぶ1日イベント',
  },
  {
    id: 2,
    title: '音楽フェスティバル',
    date: '2025-07-20',
    type: 'エンターテイメント',
    description: '地元アーティストによる野外コンサート',
  },
  {
    id: 3,
    title: 'チャリティマラソン',
    date: '2025-08-05',
    type: 'スポーツ',
    description: '環境保護のための募金イベント',
  },
];

// AuthContextのモック
jest.mock('../../contexts/AuthContext', () => {
  const originalModule = jest.requireActual('../../contexts/AuthContext');
  return {
    ...originalModule,
    useAuth: () => ({
      user: { id: 1, name: 'テストユーザー' },
      isAuthenticated: () => true,
      loading: false,
      hasRole: () => false,
    }),
  };
});

// Reactフックのモック（一度だけモック化）
jest.mock('react', () => {
  const originalReact = jest.requireActual('react');
  const originalUseState = originalReact.useState;

  return {
    ...originalReact,
    // useEffectをモック
    useEffect: jest.fn().mockImplementation((cb) => cb()),
    // useStateをモック
    useState: jest.fn().mockImplementation((initialValue) => {
      // eventsの初期化
      if (initialValue && initialValue.length === 0) {
        return [mockEvents, jest.fn()];
      }
      // isLoadingの初期化
      if (initialValue === true) {
        return [false, jest.fn()];
      }
      // その他のuseState呼び出し
      return originalUseState(initialValue);
    }),
  };
});

describe('Events Page', () => {
  beforeEach(() => {
    // 各テスト前にモックをリセット
    jest.clearAllMocks();

    // 初期DOMレンダリング
    render(
      <AuthProvider>
        <Events />
      </AuthProvider>
    );
  });

  it('イベントリストのタイトルが表示される', () => {
    // getAllByTextを使用して複数の要素から特定の要素を選択
    const pageTitle = screen
      .getAllByText('イベント一覧')
      .find((element) => element.tagName.toLowerCase() === 'h1');
    expect(pageTitle).toBeInTheDocument();
  });

  it('イベントの説明文が表示される', () => {
    expect(screen.getByText('興味のあるイベントを見つけて参加しましょう')).toBeInTheDocument();
  });

  it('イベントカードが表示される', () => {
    // 不確定な要素がある場合は、queryで存在確認
    const eventCards = screen.queryAllByTestId('event-card');
    expect(eventCards.length).toBe(3); // モックイベントが3つあることを確認

    // モックイベントタイトルが表示されていることを確認
    expect(screen.getByText('テクノロジーカンファレンス')).toBeInTheDocument();
    expect(screen.getByText('音楽フェスティバル')).toBeInTheDocument();
    expect(screen.getByText('チャリティマラソン')).toBeInTheDocument();
    
    // 読み込み中の表示は見えないはず
    expect(screen.queryByText('イベントを読み込み中...')).not.toBeInTheDocument();
  });
});
