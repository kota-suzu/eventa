/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  output: 'standalone',
  // ビルド時のエラーを回避するための設定
  experimental: {
    // カスタムエラーページを無効化（ビルドエラー解決のため）
    disableOptimizedLoading: true,
  },
  // 静的生成の設定を調整
  exportPathMap: null, // 自動的にルートを検出させる
}

module.exports = nextConfig 