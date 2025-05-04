/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  output: 'standalone',
  // ビルド時のエラーを回避するための設定
  experimental: {
    // カスタムエラーページを無効化（ビルドエラー解決のため）
    disableOptimizedLoading: true,
  },
  
  // 警告の解消: exportPathMapをnullではなくundefinedに設定
  // exportPathMap: null, // 自動的にルートを検出させる

  // API接続のためのプロキシ設定（開発環境用）
  async rewrites() {
    // 環境変数のデバッグ出力
    console.log('環境変数 NEXT_PUBLIC_API_URL:', process.env.NEXT_PUBLIC_API_URL);
    
    // APIのベースURL（環境変数がない場合のフォールバック）
    // ブラウザからアクセスする場合はlocalhostを使用
    const apiBaseUrl = process.env.NODE_ENV === 'development' 
      ? (process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001')
      : (process.env.NEXT_PUBLIC_API_URL || 'http://api:3000');
    
    // URL末尾のスラッシュを削除（一貫性のため）
    const normalizedApiUrl = apiBaseUrl.endsWith('/') 
      ? apiBaseUrl.slice(0, -1) 
      : apiBaseUrl;
    
    console.log('正規化されたAPIベースURL:', normalizedApiUrl);
    
    // 開発環境での注意事項
    if (process.env.NODE_ENV === 'development') {
      console.log('開発環境では、APIリクエストは次のパスにプロキシされます:');
      console.log(`- /api/v1/* → ${normalizedApiUrl}/api/v1/*`);
      console.log(`- /healthz → ${normalizedApiUrl}/healthz`);
    }
    
    return [
      // APIへのリクエストをプロキシ - パスプレフィックスあり
      {
        source: '/api/v1/:path*',
        destination: `${normalizedApiUrl}/api/v1/:path*`,
      },
      // APIヘルスチェック用のプロキシ
      {
        source: '/healthz',
        destination: `${normalizedApiUrl}/healthz`,
      },
      // 問題のあるパターンに対する修正（ブラケット形式の回避）
      {
        source: '/api:3000/:path*',
        destination: `${normalizedApiUrl}/:path*`,
      }
    ];
  },
};

// 環境変数のロギング
console.log('Next.js 環境設定:');
console.log('- NODE_ENV:', process.env.NODE_ENV);
console.log('- NEXT_PUBLIC_API_URL:', process.env.NEXT_PUBLIC_API_URL);

module.exports = nextConfig;
