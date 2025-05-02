import Cookies from 'js-cookie';
import axios from 'axios';

// API のベース URL を環境変数から取得
const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001/api/v1';

// API クライアントの作成
export const api = axios.create({
  baseURL: API_BASE_URL,
  withCredentials: true, // CORS with credentials サポート
});

// Cookieの有効期限（日）
const TOKEN_EXPIRY_DAYS = 7;

/**
 * トークンをCookieとして保存
 * 
 * @param {string} token - 認証トークン
 * @param {boolean} remember - ログイン状態を記憶するか
 */
export const setAuthToken = (token, remember = false) => {
  try {
    // XSS対策としてHTTPOnly Cookieを推奨するが、
    // Next.jsのAPIルートを使用していない場合はフロントのみでCookieを操作する
    const options = {
      expires: remember ? TOKEN_EXPIRY_DAYS : 1,
      secure: process.env.NODE_ENV === 'production', // 本番環境では Secure属性を有効に
      sameSite: 'Lax' // CSRF対策
    };
    
    Cookies.set('auth_token', token, options);
    
    // API クライアントにも設定
    if (token) {
      api.defaults.headers.common['Authorization'] = `Bearer ${token}`;
    }
    
    return true;
  } catch (error) {
    console.error('トークン保存エラー:', error);
    return false;
  }
};

/**
 * 認証トークンを取得
 * 
 * @returns {string|null} 保存されたトークンまたはnull
 */
export const getAuthToken = () => {
  try {
    return Cookies.get('auth_token') || null;
  } catch (error) {
    console.error('トークン取得エラー:', error);
    return null;
  }
};

/**
 * ユーザーデータをセッションストレージに保存
 * 
 * @param {Object} userData - ユーザー情報
 */
export const setUserData = (userData) => {
  if (typeof window !== 'undefined') {
    try {
      sessionStorage.setItem('user_data', JSON.stringify(userData));
      return true;
    } catch (error) {
      console.error('ユーザーデータ保存エラー:', error);
      return false;
    }
  }
  return false;
};

/**
 * ユーザーデータを取得
 * 
 * @returns {Object|null} 保存されたユーザーデータまたはnull
 */
export const getUserData = () => {
  if (typeof window !== 'undefined') {
    try {
      const data = sessionStorage.getItem('user_data');
      return data ? JSON.parse(data) : null;
    } catch (e) {
      console.error('ユーザーデータの解析エラー:', e);
      return null;
    }
  }
  return null;
};

/**
 * 認証情報をクリア
 */
export const clearAuth = () => {
  try {
    // Cookie認証トークンを削除
    Cookies.remove('auth_token', { 
      path: '/',
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'Lax'
    });
    
    // API ヘッダーからも削除
    delete api.defaults.headers.common['Authorization'];
    
    if (typeof window !== 'undefined') {
      // セッションストレージからユーザーデータを削除
      sessionStorage.removeItem('user_data');
      
      // 念のためローカルストレージからも削除を試みる（以前の実装との互換性のため）
      localStorage.removeItem('auth_token');
      localStorage.removeItem('user');
    }
    
    return true;
  } catch (error) {
    console.error('認証情報クリアエラー:', error);
    return false;
  }
};

/**
 * ユーザーが認証済みかチェック
 * 
 * @returns {boolean} 認証済みならtrue
 */
export const isAuthenticated = () => {
  return !!getAuthToken();
};

/**
 * ログイン処理
 * @param {string} email - メールアドレス
 * @param {string} password - パスワード
 * @param {boolean} remember - ログイン状態を記憶するか
 * @returns {Promise<{ok: boolean, user?: Object, message?: string}>} 
 */
export const login = async (email, password, remember = false) => {
  try {
    const response = await api.post('/auth/login', {
      email,
      password
    });
    
    if (response.status === 200) {
      const { user, token } = response.data;
      
      // トークンの保存
      setAuthToken(token, remember);
      
      // ユーザー情報の保存
      setUserData(user);
      
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

/**
 * ログアウト処理
 * @returns {Promise<boolean>} 成功したらtrue
 */
export const logout = async () => {
  try {
    // バックエンドにログアウトリクエストを送信（オプション）
    // await api.post('/auth/logout');
    
    // フロントエンドの認証情報をクリア
    return clearAuth();
  } catch (error) {
    console.error('Logout failed:', error);
    return false;
  }
}; 