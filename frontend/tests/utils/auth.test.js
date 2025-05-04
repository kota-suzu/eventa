import { getAuthToken, setAuthToken, clearAuth, getUserData, setUserData } from '../../utils/auth';
import Cookies from 'js-cookie';

// Cookiesモジュールをモック化
jest.mock('js-cookie', () => ({
  get: jest.fn(),
  set: jest.fn(),
  remove: jest.fn(),
}));

// sessionStorageのモック
const mockSessionStorage = (() => {
  let store = {};
  return {
    getItem: jest.fn(key => store[key] || null),
    setItem: jest.fn((key, value) => { store[key] = value; }),
    removeItem: jest.fn(key => { delete store[key]; }),
    clear: jest.fn(() => { store = {}; })
  };
})();

// windowオブジェクトのモック
Object.defineProperty(window, 'sessionStorage', {
  value: mockSessionStorage
});

describe('認証ユーティリティ', () => {
  // 各テスト前にモックをリセット
  beforeEach(() => {
    jest.clearAllMocks();
    mockSessionStorage.clear();
  });

  describe('getAuthToken', () => {
    it('Cookieからトークンを取得する', () => {
      // 準備
      Cookies.get.mockReturnValue('test-token');

      // 実行
      const token = getAuthToken();

      // 検証
      expect(Cookies.get).toHaveBeenCalledWith('auth_token');
      expect(token).toBe('test-token');
    });

    it('Cookieにトークンがない場合はnullを返す', () => {
      // 準備
      Cookies.get.mockReturnValue(undefined);

      // 実行
      const token = getAuthToken();

      // 検証
      expect(Cookies.get).toHaveBeenCalledWith('auth_token');
      expect(token).toBeNull();
    });
  });

  describe('setAuthToken', () => {
    it('Cookieにトークンを設定する', () => {
      // 実行
      setAuthToken('new-test-token');

      // 検証 - ここではオプションの詳細は期待値に含めないようにする
      expect(Cookies.set).toHaveBeenCalledWith('auth_token', 'new-test-token', expect.any(Object));
    });
  });

  describe('clearAuth', () => {
    it('認証情報をクリアする', () => {
      // 実行
      clearAuth();

      // 検証
      expect(Cookies.remove).toHaveBeenCalledWith('auth_token', expect.any(Object));
      expect(mockSessionStorage.removeItem).toHaveBeenCalledWith('user_data');
    });
  });

  describe('getUserData', () => {
    it('セッションストレージからユーザーデータを取得する', () => {
      // 準備
      const userData = { id: 1, name: 'テストユーザー' };
      mockSessionStorage.getItem.mockReturnValue(JSON.stringify(userData));

      // 実行
      const result = getUserData();

      // 検証
      expect(mockSessionStorage.getItem).toHaveBeenCalledWith('user_data');
      expect(result).toEqual(userData);
    });

    it('セッションストレージにユーザーデータがない場合はnullを返す', () => {
      // 準備
      mockSessionStorage.getItem.mockReturnValue(null);

      // 実行
      const result = getUserData();

      // 検証
      expect(mockSessionStorage.getItem).toHaveBeenCalledWith('user_data');
      expect(result).toBeNull();
    });

    it('不正なJSONの場合はnullを返す', () => {
      // 準備
      mockSessionStorage.getItem.mockReturnValue('invalid-json');

      // 実行
      const result = getUserData();

      // 検証
      expect(mockSessionStorage.getItem).toHaveBeenCalledWith('user_data');
      expect(result).toBeNull();
    });
  });

  describe('setUserData', () => {
    it('セッションストレージにユーザーデータを設定する', () => {
      // 準備
      const userData = { id: 1, name: 'テストユーザー' };

      // 実行
      setUserData(userData);

      // 検証
      expect(mockSessionStorage.setItem).toHaveBeenCalledWith(
        'user_data',
        JSON.stringify(userData)
      );
    });
  });
});
