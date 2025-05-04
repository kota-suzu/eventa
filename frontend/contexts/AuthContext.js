import React, { createContext, useState, useEffect, useContext } from 'react';
import { useRouter } from 'next/router';
import {
  api,
  getAuthToken,
  setAuthToken,
  clearAuth,
  getUserData,
  setUserData,
  testApiConnection,
} from '../utils/auth';

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
              const response = await api.get('auths/me');
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

  // APIの接続状態を確認
  useEffect(() => {
    // 開発環境のみAPIの接続状態を確認
    if (process.env.NODE_ENV === 'development') {
      testApiConnection().then((result) => {
        console.log('API接続テスト結果:', result);
      });
    }
  }, []);

  // ユーザー登録処理
  const register = async (userData) => {
    try {
      setLoading(true);
      console.log('登録リクエスト送信データ:', userData);

      // リクエスト前の詳細ログ
      console.log('API設定詳細:', {
        baseURL: api.defaults.baseURL,
        headers: api.defaults.headers,
        withCredentials: api.defaults.withCredentials,
      });

      // エンドポイントを明示的に指定
      const registerEndpoint = 'auths/register';
      console.log(
        `リクエスト送信先: ${api.defaults.baseURL}/${registerEndpoint}`.replace(/\/+/g, '/')
      );

      // 登録リクエスト送信
      const response = await api.post(registerEndpoint, userData);
      console.log('登録レスポンス:', response.status, response.data);

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

      // エラー詳細のログ
      if (error.response) {
        console.error('エラーレスポンス詳細:', {
          status: error.response.status,
          data: error.response.data,
          headers: error.response.headers,
        });
      } else if (error.message === 'Network Error') {
        console.error('ネットワークエラーの詳細:', {
          errorName: error.name,
          errorMessage: error.message,
          apiBaseURL: api.defaults.baseURL,
          // ブラウザの場合はCORSの情報も出力
          corsInfo:
            typeof window !== 'undefined'
              ? {
                  origin: window.location.origin,
                  protocol: window.location.protocol,
                  host: window.location.host,
                }
              : null,
        });

        // ネットワークエラー時にフェッチAPIで直接リクエストを試行
        try {
          const registerUrl = `${api.defaults.baseURL}/auths/register`.replace(/\/+/g, '/');
          console.log('直接fetchでリクエスト試行:', registerUrl);

          const fetchResponse = await fetch(registerUrl, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
            },
            body: JSON.stringify(userData),
            credentials: 'include',
          });

          const fetchData = await fetchResponse.json();
          console.log('Fetch試行結果:', {
            status: fetchResponse.status,
            ok: fetchResponse.ok,
            data: fetchData,
          });

          // Fetchが成功した場合はその結果を利用
          if (fetchResponse.ok && fetchData.token) {
            const { user, token } = fetchData;

            // トークンの保存
            setAuthToken(token);
            setToken(token);

            // ユーザー情報の保存
            setUserData(user);
            setUser(user);

            return { ok: true, user };
          }
        } catch (fetchError) {
          console.error('Fetch試行もエラー:', fetchError);
        }
      }

      return {
        ok: false,
        message:
          error.response?.data?.error ||
          error.response?.data?.errors?.join(', ') ||
          '登録処理中にエラーが発生しました',
      };
    } finally {
      setLoading(false);
    }
  };

  // ログイン処理
  const login = async (email, password, remember = false) => {
    try {
      setLoading(true);
      const loginEndpoint = 'auths/login';
      console.log(
        `ログインリクエスト送信先: ${api.defaults.baseURL}/${loginEndpoint}`.replace(/\/+/g, '/')
      );

      const response = await api.post(loginEndpoint, {
        email,
        password,
        remember,
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
        message: error.response?.data?.error || 'ログイン中にエラーが発生しました',
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
    apiClient: api,
  };

  return <AuthContext.Provider value={contextValue}>{children}</AuthContext.Provider>;
};
