import Cookies from 'js-cookie';

// Cookieの有効期限（日）
const TOKEN_EXPIRY_DAYS = 7;

/**
 * トークンをCookieとして保存
 * 
 * @param {string} token - 認証トークン
 * @param {boolean} remember - ログイン状態を記憶するか
 */
export const setAuthToken = (token, remember = false) => {
  // XSS対策としてHTTPOnly Cookieを推奨するが、
  // Next.jsのAPIルートを使用していない場合はフロントのみでCookieを操作する
  const options = {
    expires: remember ? TOKEN_EXPIRY_DAYS : 1,
    secure: process.env.NODE_ENV === 'production', // 本番環境では Secure属性を有効に
    sameSite: 'Lax' // CSRF対策
  };
  
  Cookies.set('auth_token', token, options);
};

/**
 * 認証トークンを取得
 * 
 * @returns {string|null} 保存されたトークンまたはnull
 */
export const getAuthToken = () => {
  return Cookies.get('auth_token') || null;
};

/**
 * ユーザーデータをセッションストレージに保存
 * 
 * @param {Object} userData - ユーザー情報
 */
export const setUserData = (userData) => {
  if (typeof window !== 'undefined') {
    sessionStorage.setItem('user_data', JSON.stringify(userData));
  }
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
  Cookies.remove('auth_token');
  
  if (typeof window !== 'undefined') {
    sessionStorage.removeItem('user_data');
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