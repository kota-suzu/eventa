import React from 'react';
import { render, screen, act } from '@testing-library/react';
import EventDetail from '../../pages/events/[id]';
import { AuthProvider } from '../../contexts/AuthContext';

// useRouterをモック化
jest.mock('next/router', () => ({
  useRouter: () => ({
    query: { id: '1' },
    push: jest.fn(),
  }),
}));

// AuthContextのモック
jest.mock('../../contexts/AuthContext', () => {
  const originalModule = jest.requireActual('../../contexts/AuthContext');
  return {
    ...originalModule,
    useAuth: () => ({
      user: { id: 1, name: 'テストユーザー' },
      isAuthenticated: () => true,
      loading: false,
    }),
  };
});

// イベントデータのモック
const mockEvent = {
  id: 1,
  title: 'テストイベント',
  description: 'これはテストイベントの説明です。',
  date: '2023-12-25',
  time: '18:00',
  location: '東京',
  organizer: 'テスト主催者',
  capacity: 50,
  participants: 25,
  image: '/images/event1.jpg',
};

// カスタムマッチャ関数 - より厳密な比較
const textContentMatcher = (text) => {
  return (content, element) => {
    // textが数値の場合、数値変換して比較
    if (!isNaN(text)) {
      return (
        element.textContent.includes(String(text)) &&
        // 数値の前後に他の数字がないことを確認（25が250などの一部にマッチしないように）
        (element.textContent.trim() === String(text) ||
          element.textContent.match(new RegExp(`\\b${text}\\b`)))
      );
    }
    return element.textContent.includes(text);
  };
};

// useStateのモック（一度だけモック化）
jest.mock('react', () => {
  const originalReact = jest.requireActual('react');

  // オリジナルのuseStateを保存
  const originalUseState = originalReact.useState;

  // モック用のuseState
  const mockUseState = jest.fn().mockImplementation((initialState) => {
    // isLoadingの場合
    if (initialState === true) {
      return [false, jest.fn()];
    }
    // eventの場合
    if (initialState === null) {
      return [mockEvent, jest.fn()];
    }
    // その他のケース
    return originalUseState(initialState);
  });

  return {
    ...originalReact,
    useState: mockUseState,
  };
});

describe('EventDetail Page', () => {
  beforeEach(() => {
    // useEffectのモック
    jest.spyOn(React, 'useEffect').mockImplementation((f) => f());

    // コンポーネントのレンダリング
    render(
      <AuthProvider>
        <EventDetail />
      </AuthProvider>
    );
  });

  it('イベントのタイトルが表示される', () => {
    expect(screen.getByText('テストイベント')).toBeInTheDocument();
  });

  it('イベントの詳細情報が表示される', () => {
    expect(screen.getByText('これはテストイベントの説明です。')).toBeInTheDocument();

    // queryAllByTextを使用して複数の要素があっても問題ないように
    const dateElements = screen.queryAllByText((content, element) => {
      return element.textContent.includes('2023-12-25');
    });
    expect(dateElements.length).toBeGreaterThan(0);

    const locationElements = screen.queryAllByText((content, element) => {
      return element.textContent.includes('東京');
    });
    expect(locationElements.length).toBeGreaterThan(0);

    const organizerElements = screen.queryAllByText((content, element) => {
      return element.textContent.includes('テスト主催者');
    });
    expect(organizerElements.length).toBeGreaterThan(0);
  });

  it('参加ボタンが表示される', () => {
    expect(screen.getByText('参加申し込み')).toBeInTheDocument();
  });

  it('参加状況が表示される', () => {
    // 25と50を含むテキストを検索 - 複数マッチする場合はgetAllByTextを使用
    const participantsElements = screen.getAllByText(textContentMatcher('25'));
    expect(participantsElements.length).toBeGreaterThan(0);

    const capacityElements = screen.getAllByText(textContentMatcher('50'));
    expect(capacityElements.length).toBeGreaterThan(0);

    // プログレスバーの存在を確認
    const progressBar = document.querySelector('div[style*="width: 50%"]');
    expect(progressBar).toBeInTheDocument();
  });
});
