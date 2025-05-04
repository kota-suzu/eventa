/**
 * API通信のためのユーティリティ関数
 */
import axios from 'axios';
import Router from 'next/router';
import { logout } from './auth';

// API のベース URL を環境変数から取得
const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001/api/v1';

// APIクライアントの作成
const apiClient = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
  withCredentials: true, // クッキーを含める設定
});

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
  const url = `${API_BASE_URL}${endpoint}`;

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

// ログアウト
export const logout = () => {
  localStorage.removeItem('auth_token');
};

export default apiClient;
