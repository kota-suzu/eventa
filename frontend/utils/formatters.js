/**
 * 通貨フォーマットユーティリティ
 */

/**
 * 金額を通貨フォーマットに変換
 * @param {number} amount 金額
 * @param {string} currency 通貨コード (例: 'JPY', 'USD', 'TWD')
 * @returns {string} フォーマット済み金額 (例: ¥1,000、$10.00など)
 */
export const formatCurrency = (amount, currency = 'JPY') => {
  return new Intl.NumberFormat('ja-JP', {
    style: 'currency',
    currency: currency,
  }).format(amount);
};

/**
 * 数値をカンマ区切りフォーマットに変換
 * @param {number} value 数値
 * @returns {string} カンマ区切り数値 (例: 1,000)
 */
export const formatNumber = (value) => {
  return new Intl.NumberFormat('ja-JP').format(value);
};
