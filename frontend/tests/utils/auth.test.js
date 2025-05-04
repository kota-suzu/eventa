import { getAuthToken, setAuthToken, clearAuth, getUserData, setUserData } from '../../utils/auth';
import Cookies from 'js-cookie';

// Cookiesモジュールをモック化
jest.mock('js-cookie', () => ({
  get: jest.fn(),
  set: jest.fn(),
  remove: jest.fn(),
}));

describe('認証ユーティリティ', () => {
  // 各テスト前にモックをリセット
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('getAuthToken', () => {
    it('Cookieからトークンを取得する', () => {
      // 準備
      Cookies.get.mockReturnValue('test-token');

      // 実行
      const token = getAuthToken();

      // 検証
      expect(Cookies.get).toHaveBeenCalledWith('token');
      expect(token).toBe('test-token');
    });

    it('Cookieにトークンがない場合はnullを返す', () => {
      // 準備
      Cookies.get.mockReturnValue(undefined);

      // 実行
      const token = getAuthToken();

      // 検証
      expect(Cookies.get).toHaveBeenCalledWith('token');
      expect(token).toBeNull();
    });
  });

  describe('setAuthToken', () => {
    it('Cookieにトークンを設定する', () => {
      // 実行
      setAuthToken('new-test-token');

      // 検証 - ここではオプションの詳細は期待値に含めないようにする
      expect(Cookies.set).toHaveBeenCalledWith('token', 'new-test-token', expect.any(Object));
    });
  });

  describe('clearAuth', () => {
    it('認証情報をクリアする', () => {
      // 実行
      clearAuth();

      // 検証
      expect(Cookies.remove).toHaveBeenCalledWith('token');
      expect(Cookies.remove).toHaveBeenCalledWith('user');
    });
  });

  describe('getUserData', () => {
    it('Cookieからユーザーデータを取得する', () => {
      // 準備
      const userData = { id: 1, name: 'テストユーザー' };
      Cookies.get.mockReturnValue(JSON.stringify(userData));

      // 実行
      const result = getUserData();

      // 検証
      expect(Cookies.get).toHaveBeenCalledWith('user');
      expect(result).toEqual(userData);
    });

    it('Cookieにユーザーデータがない場合はnullを返す', () => {
      // 準備
      Cookies.get.mockReturnValue(undefined);

      // 実行
      const result = getUserData();

      // 検証
      expect(Cookies.get).toHaveBeenCalledWith('user');
      expect(result).toBeNull();
    });

    it('不正なJSONの場合はnullを返す', () => {
      // 準備
      Cookies.get.mockReturnValue('invalid-json');

      // 実行
      const result = getUserData();

      // 検証
      expect(Cookies.get).toHaveBeenCalledWith('user');
      expect(result).toBeNull();
    });
  });

  describe('setUserData', () => {
    it('Cookieにユーザーデータを設定する', () => {
      // 準備
      const userData = { id: 1, name: 'テストユーザー' };

      // 実行
      setUserData(userData);

      // 検証 - ここではオプションの詳細は期待値に含めないようにする
      expect(Cookies.set).toHaveBeenCalledWith(
        'user',
        JSON.stringify(userData),
        expect.any(Object)
      );
    });
  });
});
