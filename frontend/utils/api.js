/**
 * API通信のためのユーティリティ関数
 */
import axios from 'axios';
import Router from 'next/router';
import { logout } from './auth';

// API パスのプレフィックス
const API_PATH_PREFIX = '/api/v1';

// APIクライアントの作成
const apiClient = axios.create({
  // 相対パスを使用（Next.jsのプロキシ経由でアクセス）
  baseURL: API_PATH_PREFIX,
  headers: {
    'Content-Type': 'application/json',
  },
  withCredentials: true, // クッキーを含める設定
});

// デバッグ用コンソール出力
if (typeof window !== 'undefined' && process.env.NODE_ENV === 'development') {
  console.log('API Client設定:', {
    環境変数: process.env.NEXT_PUBLIC_API_URL,
    相対パス: true,
    パスプレフィックス: API_PATH_PREFIX,
    最終URL: apiClient.defaults.baseURL,
  });
}

// リクエスト時に認証トークンを設定
apiClient.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('auth_token');
    if (token) {
      config.headers['Authorization'] = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// 401エラー時にはログアウト処理
apiClient.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      logout();
      Router.push('/login');
    }

    // ネットワークエラーの詳細ログ
    if (error.message === 'Network Error') {
      console.error('APIネットワークエラー:', {
        baseURL: apiClient.defaults.baseURL,
        requestUrl: error.config?.url,
        fullUrl: `${apiClient.defaults.baseURL}/${error.config?.url}`.replace(/\/+/g, '/'),
        method: error.config?.method,
        headers: error.config?.headers,
        data: error.config?.data,
      });
    }

    return Promise.reject(error);
  }
);

/**
 * APIリクエストを行う汎用関数
 * @param {string} endpoint - APIエンドポイント（/から始まる）
 * @param {Object} options - fetchオプション
 * @returns {Promise<any>} レスポンスデータ
 */
export async function fetchApi(endpoint, options = {}) {
  // 相対パスで指定（baseURLが使われる）
  const url = endpoint.startsWith('/')
    ? `${apiClient.defaults.baseURL}${endpoint}`
    : `${apiClient.defaults.baseURL}/${endpoint}`;

  if (process.env.NODE_ENV === 'development') {
    console.log(`API fetchリクエスト: ${url}`);
  }

  // デフォルトのヘッダーを設定
  const headers = {
    'Content-Type': 'application/json',
    ...options.headers,
  };

  // 認証トークンがある場合は追加
  const token = localStorage.getItem('auth_token');
  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }

  try {
    const response = await fetch(url, {
      ...options,
      headers,
    });

    // レスポンスをJSONとしてパース
    const data = await response.json();

    // エラーレスポンスの場合は例外をスロー
    if (!response.ok) {
      const error = new Error(data.message || '通信エラーが発生しました');
      error.status = response.status;
      error.data = data;
      throw error;
    }

    return data;
  } catch (error) {
    console.error('API リクエストエラー:', error);
    throw error;
  }
}

/**
 * GET リクエスト
 * @param {string} endpoint - APIエンドポイント
 * @param {Object} options - その他のオプション
 * @returns {Promise<any>}
 */
export function get(endpoint, options = {}) {
  return fetchApi(endpoint, {
    method: 'GET',
    ...options,
  });
}

/**
 * POST リクエスト
 * @param {string} endpoint - APIエンドポイント
 * @param {Object} data - リクエストボディ
 * @param {Object} options - その他のオプション
 * @returns {Promise<any>}
 */
export function post(endpoint, data, options = {}) {
  return fetchApi(endpoint, {
    method: 'POST',
    body: JSON.stringify(data),
    ...options,
  });
}

/**
 * PUT リクエスト
 * @param {string} endpoint - APIエンドポイント
 * @param {Object} data - リクエストボディ
 * @param {Object} options - その他のオプション
 * @returns {Promise<any>}
 */
export function put(endpoint, data, options = {}) {
  return fetchApi(endpoint, {
    method: 'PUT',
    body: JSON.stringify(data),
    ...options,
  });
}

/**
 * PATCH リクエスト
 * @param {string} endpoint - APIエンドポイント
 * @param {Object} data - リクエストボディ
 * @param {Object} options - その他のオプション
 * @returns {Promise<any>}
 */
export function patch(endpoint, data, options = {}) {
  return fetchApi(endpoint, {
    method: 'PATCH',
    body: JSON.stringify(data),
    ...options,
  });
}

/**
 * DELETE リクエスト
 * @param {string} endpoint - APIエンドポイント
 * @param {Object} options - その他のオプション
 * @returns {Promise<any>}
 */
export function del(endpoint, options = {}) {
  return fetchApi(endpoint, {
    method: 'DELETE',
    ...options,
  });
}

// チケット予約作成API
export const createReservation = async (reservationData) => {
  const response = await apiClient.post('/ticket_reservations', reservationData);
  return response.data;
};

// イベントのチケット一覧取得API
export const getEventTickets = async (eventId) => {
  const response = await apiClient.get(`/events/${eventId}/tickets`);
  return response.data;
};

// ユーザーの予約一覧取得API
export const getUserReservations = async () => {
  const response = await apiClient.get('/user/reservations');
  return response.data;
};

// ログインAPI
export const login = async (credentials) => {
  const response = await apiClient.post('/login', credentials);
  const { token, user } = response.data;

  // トークンをlocalStorageに保存
  localStorage.setItem('auth_token', token);

  return user;
};

export default apiClient;
