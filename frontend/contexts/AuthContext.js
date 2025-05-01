import { createContext, useContext, useState, useEffect } from 'react';
import { useRouter } from 'next/router';
import { 
  setAuthToken, 
  getAuthToken, 
  setUserData, 
  getUserData, 
  clearAuth, 
  isAuthenticated as checkIsAuthenticated 
} from '../utils/auth';

const AuthContext = createContext({
  isAuthenticated: false,
  user: null,
  login: () => {},
  logout: () => {},
  loading: true
});

export const useAuth = () => useContext(AuthContext);

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const router = useRouter();

  // アプリロード時に認証状態を確認
  useEffect(() => {
    const initAuth = async () => {
      try {
        // 認証状態の確認
        if (checkIsAuthenticated()) {
          // セッションストレージからユーザーデータを取得
          const userData = getUserData();

          if (userData) {
            // 実際のアプリケーションでは、ここでトークンの有効性を確認する
            // 例: APIを呼び出して現在のユーザー情報を取得
            setUser(userData);
          }
        }
      } catch (error) {
        console.error('認証初期化エラー:', error);
        // エラーが発生した場合、認証情報をクリア
        clearAuth();
        setUser(null);
      } finally {
        setLoading(false);
      }
    };

    initAuth();
  }, []);

  // ログイン処理
  const login = (token, userData, remember = false) => {
    setAuthToken(token, remember);
    setUserData(userData);
    setUser(userData);
  };

  // ログアウト処理
  const logout = () => {
    clearAuth();
    setUser(null);
    router.push('/login');
  };

  return (
    <AuthContext.Provider
      value={{
        isAuthenticated: !!user,
        user,
        login,
        logout,
        loading
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}; 