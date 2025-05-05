const nextJest = require('next/jest');

const createJestConfig = nextJest({
  // next.config.jsとテスト環境用の.envファイルが配置されたディレクトリへのパス
  dir: './',
});

// Jestに渡すカスタム設定
const customJestConfig = {
  // テストを検索するディレクトリを追加
  roots: ['<rootDir>/tests/'],

  // テスト環境をDOMシミュレーションのjsdomに設定
  testEnvironment: 'jest-environment-jsdom',

  // テストファイルのパターンを指定
  testMatch: ['<rootDir>/tests/**/*.test.js', '<rootDir>/tests/**/*.test.jsx'],

  // モック設定
  moduleNameMapper: {
    // スタイルモジュールをモック
    '\\.(css|less|scss|sass)$': '<rootDir>/tests/__mocks__/styleMock.js',
    // 画像をモック
    '\\.(jpg|jpeg|png|gif|webp|svg)$': '<rootDir>/tests/__mocks__/fileMock.js',
  },

  // テスト実行前にセットアップスクリプトを実行
  setupFilesAfterEnv: ['<rootDir>/tests/jest.setup.js'],

  // カバレッジ設定
  collectCoverage: true,
  collectCoverageFrom: [
    'components/**/*.{js,jsx}',
    'contexts/**/*.{js,jsx}',
    'pages/**/*.{js,jsx}',
    'utils/**/*.{js,jsx}',
    '!**/*.d.ts',
    '!**/node_modules/**',
  ],

  // JSXファイルも処理対象に含める
  moduleFileExtensions: ['js', 'jsx', 'json'],

  // テスト環境の環境変数を設定
  testEnvironmentOptions: {
    customExportConditions: ['node', 'node-addons'],
  },

  // テスト環境の環境変数
  setupFiles: ['<rootDir>/tests/setEnvVars.js'],
};

// createJestConfigを使用して、Next.jsの設定を組み込んだJest設定を作成
module.exports = createJestConfig(customJestConfig);
