import React from 'react';
import { render, screen, waitFor } from '@testing-library/react';
import { AuthProvider, useAuth } from '../../contexts/AuthContext';
import { act } from 'react-dom/test-utils';

// AuthProviderをモック
jest.mock('../../utils/auth', () => ({
  api: {
    post: jest.fn().mockResolvedValue({
      status: 200,
      data: {
        user: { id: 1, name: 'テストユーザー', email: 'test@example.com' },
        token: 'dummy-token',
      },
    }),
    get: jest.fn().mockResolvedValue({
      status: 200,
      data: { user: { id: 1, name: 'テストユーザー', email: 'test@example.com' } },
    }),
  },
  getAuthToken: jest.fn().mockReturnValue(null),
  setAuthToken: jest.fn(),
  clearAuth: jest.fn(),
  getUserData: jest.fn().mockReturnValue(null),
  setUserData: jest.fn(),
}));

// テスト用コンポーネント
const TestComponent = () => {
  const { user, isAuthenticated, loading } = useAuth();
  return (
    <div>
      <div data-testid="loading">{loading ? 'Loading...' : 'Not loading'}</div>
      <div data-testid="authenticated">
        {isAuthenticated() ? 'Authenticated' : 'Not authenticated'}
      </div>
      <div data-testid="user-name">{user ? user.name : 'No user'}</div>
    </div>
  );
};

describe('AuthContext', () => {
  it('初期状態では認証されていない', async () => {
    render(
      <AuthProvider>
        <TestComponent />
      </AuthProvider>
    );

    // 初期状態ではloadingが完了するまで待つ
    await waitFor(() => {
      expect(screen.getByTestId('loading')).toHaveTextContent('Not loading');
    });

    // 認証されていないことを確認
    expect(screen.getByTestId('authenticated')).toHaveTextContent('Not authenticated');
    expect(screen.getByTestId('user-name')).toHaveTextContent('No user');
  });

  // 他のテストケースも追加可能
  // 例: ログイン、ログアウト、登録など
});
