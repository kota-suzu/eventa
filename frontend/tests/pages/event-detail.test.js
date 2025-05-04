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

// カスタムマッチャ関数
const textContentMatcher = (text) => {
  return (content, element) => {
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
    jest.spyOn(React, 'useEffect').mockImplementation(f => f());
    
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
    expect(screen.getByText(textContentMatcher('2023-12-25'))).toBeInTheDocument();
    expect(screen.getByText(textContentMatcher('東京'))).toBeInTheDocument();
    expect(screen.getByText(textContentMatcher('テスト主催者'))).toBeInTheDocument();
  });

  it('参加ボタンが表示される', () => {
    expect(screen.getByText('参加申し込み')).toBeInTheDocument();
  });

  it('参加状況が表示される', () => {
    // 25と50を含むテキストを検索
    const participantsElement = screen.getByText(textContentMatcher('25'));
    expect(participantsElement).toBeInTheDocument();
    
    const capacityElement = screen.getByText(textContentMatcher('50'));
    expect(capacityElement).toBeInTheDocument();
    
    // プログレスバーの存在を確認
    const progressBar = document.querySelector('div[style*="width: 50%"]');
    expect(progressBar).toBeInTheDocument();
  });
}); 