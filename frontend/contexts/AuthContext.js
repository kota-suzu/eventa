import React, { createContext, useState, useEffect, useContext } from 'react';
import { useRouter } from 'next/router';
import axios from 'axios';

// APIのURLを環境変数から取得
const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001/api/v1';

// 専用のaxiosインスタンスを作成
const api = axios.create({
  baseURL: API_URL
});

// ローカルストレージのSSR安全なアクセス
const getFromStorage = (key) => {
  if (typeof window === 'undefined') return null;
  return localStorage.getItem(key);
};

const saveToStorage = (key, value) => {
  if (typeof window === 'undefined') return;
  localStorage.setItem(key, value);
};

const removeFromStorage = (key) => {
  if (typeof window === 'undefined') return;
  localStorage.removeItem(key);
};

export const AuthContext = createContext();

// 便利なカスタムフック
export const useAuth = () => useContext(AuthContext);

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [token, setToken] = useState(null);
  const [loading, setLoading] = useState(true);
  const router = useRouter();

  // トークンをAPIクライアントに設定する関数
  const setAuthToken = (token) => {
    if (token) {
      api.defaults.headers.common['Authorization'] = `Bearer ${token}`;
    } else {
      delete api.defaults.headers.common['Authorization'];
    }
  };

  // 初期化時にローカルストレージからトークンを取得
  useEffect(() => {
    const storedToken = getFromStorage('auth_token');
    const storedUser = getFromStorage('user');

    if (storedToken && storedUser) {
      setToken(storedToken);
      setUser(JSON.parse(storedUser));
      
      // トークンをAPIクライアントにセット
      setAuthToken(storedToken);
    }

    setLoading(false);
  }, []);

  // ユーザー登録処理 - 拡張された戻り値
  const register = async (userData) => {
    try {
      const response = await api.post(`/auth/register`, userData);
      
      if (response.status === 201) {
        const { user, token } = response.data;
        
        // トークンとユーザー情報を保存
        saveToStorage('auth_token', token);
        saveToStorage('user', JSON.stringify(user));
        
        // 状態を更新
        setUser(user);
        setToken(token);
        
        // トークンをAPIクライアントにセット
        setAuthToken(token);
        
        return { ok: true, user };
      }
      return { ok: false, message: '登録処理に失敗しました' };
    } catch (error) {
      console.error('Registration failed:', error);
      return { 
        ok: false, 
        message: error.response?.data?.errors?.join(', ') || '登録処理中にエラーが発生しました' 
      };
    }
  };

  // ログイン処理 - 拡張された戻り値
  const login = async (email, password) => {
    try {
      const response = await api.post(`/auth/login`, {
        email,
        password
      });
      
      if (response.status === 200) {
        const { user, token } = response.data;
        
        // トークンとユーザー情報を保存
        saveToStorage('auth_token', token);
        saveToStorage('user', JSON.stringify(user));
        
        // 状態を更新
        setUser(user);
        setToken(token);
        
        // トークンをAPIクライアントにセット
        setAuthToken(token);
        
        return { ok: true, user };
      }
      return { ok: false, message: 'ログインに失敗しました' };
    } catch (error) {
      console.error('Login failed:', error);
      return { 
        ok: false, 
        message: error.response?.data?.error || 'ログイン中にエラーが発生しました' 
      };
    }
  };

  // ログアウト処理
  const logout = () => {
    // トークンとユーザー情報をクリア
    removeFromStorage('auth_token');
    removeFromStorage('user');
    
    // 状態を更新
    setUser(null);
    setToken(null);
    
    // APIクライアントからトークンを削除
    setAuthToken(null);
    
    // ホームへリダイレクト
    router.push('/login');
  };
  
  // 認証状態のチェック
  const isAuthenticated = () => {
    return !!token;
  };
  
  // ユーザーロールに基づく権限チェック
  const hasRole = (role) => {
    if (!user) return false;
    return user.role === role;
  };

  // APIクライアントを公開
  const apiClient = api;

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
    apiClient
  };

  return (
    <AuthContext.Provider value={contextValue}>
      {children}
    </AuthContext.Provider>
  );
};
