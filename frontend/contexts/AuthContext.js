import React, { createContext, useState, useEffect, useContext } from 'react';
import { useRouter } from 'next/router';
import { api, getAuthToken, setAuthToken, clearAuth, getUserData, setUserData } from '../utils/auth';

export const AuthContext = createContext();

// カスタムフック
export const useAuth = () => useContext(AuthContext);

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [token, setToken] = useState(null);
  const [loading, setLoading] = useState(true);
  const router = useRouter();

  // 初期化時に認証状態を復元
  useEffect(() => {
    const initAuth = async () => {
      try {
        // トークンの取得
        const storedToken = getAuthToken();
        
        if (storedToken) {
          setToken(storedToken);
          
          // ユーザー情報取得（セッションストレージまたはAPIから）
          let userData = getUserData();
          
          // セッションストレージにデータがなければAPIから再取得
          if (!userData) {
            try {
              // APIからユーザー情報取得
              const response = await api.get('/auth/me');
              userData = response.data.user;
              // セッションストレージに保存
              setUserData(userData);
            } catch (error) {
              console.warn('ユーザー情報の再取得に失敗:', error);
              // トークンが無効な場合は認証情報をクリア
              clearAuth();
              setToken(null);
              setUser(null);
            }
          }
          
          if (userData) {
            setUser(userData);
          }
        }
      } catch (error) {
        console.error('認証状態の初期化エラー:', error);
      } finally {
        setLoading(false);
      }
    };
    
    initAuth();
  }, []);

  // ユーザー登録処理
  const register = async (userData) => {
    try {
      setLoading(true);
      const response = await api.post('/auth/register', userData);
      
      if (response.status === 201) {
        const { user, token } = response.data;
        
        // トークンの保存
        setAuthToken(token);
        setToken(token);
        
        // ユーザー情報の保存
        setUserData(user);
        setUser(user);
        
        return { ok: true, user };
      }
      return { ok: false, message: '登録処理に失敗しました' };
    } catch (error) {
      console.error('Registration failed:', error);
      return { 
        ok: false, 
        message: error.response?.data?.errors?.join(', ') || '登録処理中にエラーが発生しました' 
      };
    } finally {
      setLoading(false);
    }
  };

  // ログイン処理
  const login = async (email, password, remember = false) => {
    try {
      setLoading(true);
      const response = await api.post('/auth/login', {
        email,
        password,
        remember
      });
      
      if (response.status === 200) {
        const { user, token } = response.data;
        
        // トークンの保存
        setAuthToken(token, remember);
        setToken(token);
        
        // ユーザー情報の保存
        setUserData(user);
        setUser(user);
        
        return { ok: true, user };
      }
      return { ok: false, message: 'ログインに失敗しました' };
    } catch (error) {
      console.error('Login failed:', error);
      return { 
        ok: false, 
        message: error.response?.data?.error || 'ログイン中にエラーが発生しました' 
      };
    } finally {
      setLoading(false);
    }
  };

  // ログアウト処理
  const logout = () => {
    try {
      // デバッグ用ログ
      console.log('Logout process started in AuthContext');
      
      // 認証情報をクリア
      clearAuth();
      
      // 状態を更新
      setUser(null);
      setToken(null);
      
      console.log('State cleared, redirecting...');
      
      // 遅延してリダイレクト (Next.jsの状態更新を待つ)
      setTimeout(() => {
        router.push('/');
      }, 100);
      
      return true;
    } catch (error) {
      console.error('Logout error:', error);
      return false;
    }
  };
  
  // 認証状態のチェック
  const isAuthenticated = () => {
    return !!token;
  };
  
  // ユーザーロールに基づく権限チェック
  const hasRole = (role) => {
    if (!user) return false;
    return user.role === role || user.attributes?.role === role;
  };

  // コンテキスト値
  const contextValue = {
    user,
    token,
    loading,
    register,
    login,
    logout,
    isAuthenticated,
    hasRole,
    apiClient: api
  };

  return (
    <AuthContext.Provider value={contextValue}>
      {children}
    </AuthContext.Provider>
  );
};
