/**
 * API通信のためのユーティリティ関数
 */
import { getAuthToken } from './auth';

// API のベース URL を環境変数から取得
const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001';

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
  const token = getAuthToken();
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