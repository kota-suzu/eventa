# フロントエンドアプリケーションの認証統合ガイド

**ステータス**: Active  
**作成日**: 2025-05-04  
**作成者**: Frontend Team

## 目次

1. [概要](#概要)
2. [認証フロー](#認証フロー)
3. [APIエンドポイント](#apiエンドポイント)
4. [フロントエンド実装ガイド](#フロントエンド実装ガイド)
5. [トークン管理](#トークン管理)
6. [セキュリティ考慮事項](#セキュリティ考慮事項)
7. [テスト方法](#テスト方法)
8. [トラブルシューティング](#トラブルシューティング)

## 概要

Eventaフロントエンドアプリケーションは、バックエンドAPIとの通信に JWT（JSON Web Token）を使用する認証システムを実装しています。このドキュメントでは、フロントエンドとバックエンドの認証統合方法について説明します。

## 認証フロー

Eventaは以下の認証フローを使用しています：

1. **ユーザー登録/ログイン**:
   - ユーザーがフォームに認証情報を入力
   - フロントエンドがAPIにリクエストを送信
   - 成功時、APIはアクセストークン（短期間有効）とリフレッシュトークン（長期間有効）を返す

2. **認証状態の保持**:
   - アクセストークンは通常メモリ内またはセキュアなストレージに保存
   - リフレッシュトークンはHttpOnlyクッキーに保存（XSS対策）

3. **API通信**:
   - 各APIリクエストにアクセストークンをAuthorizationヘッダーで添付
   - トークン形式: `Bearer {token}`

4. **トークン更新フロー**:
   - アクセストークンの期限切れ時（401エラー）
   - リフレッシュトークンを使って新しいアクセストークンを取得
   - リフレッシュトークンも期限切れ → ユーザーを再ログイン画面へ誘導

## APIエンドポイント

認証関連のAPIエンドポイント：

| エンドポイント               | メソッド | 説明                           | リクエスト/レスポンス例 |
|------------------------------|----------|--------------------------------|--------------------------|
| `/api/v1/auth/register`      | POST     | 新規ユーザー登録               | [詳細](#ユーザー登録)    |
| `/api/v1/auth/login`         | POST     | ユーザーログイン               | [詳細](#ユーザーログイン)|
| `/api/v1/auth/refresh`       | POST     | アクセストークン更新           | [詳細](#トークン更新)    |
| `/api/v1/auth/logout`        | DELETE   | ログアウト                     | [詳細](#ログアウト)      |

### ユーザー登録

**リクエスト:**
```json
POST /api/v1/auth/register
Content-Type: application/json

{
  "user": {
    "email": "user@example.com",
    "password": "password123",
    "password_confirmation": "password123",
    "name": "Example User"
  }
}
```

**レスポンス:**
```json
Status: 201 Created
Content-Type: application/json

{
  "token": "eyJhbGciOiJIUzI1NiJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiJ9...",
  "user": {
    "id": 1,
    "email": "user@example.com",
    "name": "Example User",
    "created_at": "2025-04-15T12:34:56.789Z",
    "updated_at": "2025-04-15T12:34:56.789Z"
  }
}
```

### ユーザーログイン

**リクエスト:**
```json
POST /api/v1/auth/login
Content-Type: application/json

{
  "auth": {
    "email": "user@example.com",
    "password": "password123"
  }
}
```

**レスポンス:**
```json
Status: 200 OK
Content-Type: application/json
Set-Cookie: jwt=eyJhbGciOiJIUzI1...; HttpOnly; Secure; SameSite=Lax
Set-Cookie: refresh_token=eyJhbGciOiJIUzI1...; HttpOnly; Secure; SameSite=Lax

{
  "token": "eyJhbGciOiJIUzI1NiJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiJ9...",
  "user": {
    "id": 1,
    "email": "user@example.com",
    "name": "Example User",
    "created_at": "2025-04-15T12:34:56.789Z",
    "updated_at": "2025-04-15T12:34:56.789Z"
  }
}
```

### トークン更新

**リクエスト:**
```json
POST /api/v1/auth/refresh
Content-Type: application/json
X-Refresh-Token: eyJhbGciOiJIUzI1NiJ9...
```

または、リフレッシュトークンがCookieに保存されている場合は空のリクエストボディでも可能：

```json
POST /api/v1/auth/refresh
Content-Type: application/json
```

**レスポンス:**
```json
Status: 200 OK
Content-Type: application/json
Set-Cookie: jwt=eyJhbGciOiJIUzI1...; HttpOnly; Secure; SameSite=Lax

{
  "token": "eyJhbGciOiJIUzI1NiJ9...",
  "user": {
    "id": 1,
    "email": "user@example.com",
    "name": "Example User",
    "created_at": "2025-04-15T12:34:56.789Z",
    "updated_at": "2025-04-15T12:34:56.789Z"
  }
}
```

### ログアウト

**リクエスト:**
```json
DELETE /api/v1/auth/logout
Content-Type: application/json
Authorization: Bearer eyJhbGciOiJIUzI1NiJ9...
```

**レスポンス:**
```json
Status: 200 OK
Content-Type: application/json
Set-Cookie: jwt=; HttpOnly; Secure; SameSite=Lax; Max-Age=0
Set-Cookie: refresh_token=; HttpOnly; Secure; SameSite=Lax; Max-Age=0

{
  "message": "Successfully logged out."
}
```

## フロントエンド実装ガイド

### React + TypeScriptでの実装例

#### 1. 認証コンテキスト

`src/contexts/AuthContext.tsx`
```tsx
import React, { createContext, useState, useContext, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { jwtDecode } from 'jwt-decode';
import api from '../services/api';

interface User {
  id: number;
  email: string;
  name: string;
}

interface AuthContextType {
  user: User | null;
  token: string | null;
  loading: boolean;
  login: (email: string, password: string) => Promise<void>;
  register: (userData: RegisterData) => Promise<void>;
  logout: () => Promise<void>;
  isAuthenticated: () => boolean;
}

interface RegisterData {
  email: string;
  password: string;
  password_confirmation: string;
  name: string;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [user, setUser] = useState<User | null>(null);
  const [token, setToken] = useState<string | null>(localStorage.getItem('token'));
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  // 初期化時にトークンの有効性チェック
  useEffect(() => {
    const initAuth = async () => {
      const storedToken = localStorage.getItem('token');
      
      if (storedToken) {
        try {
          // トークンの有効期限をチェック
          const decodedToken = jwtDecode<{ exp: number }>(storedToken);
          const isExpired = decodedToken.exp * 1000 < Date.now();
          
          if (isExpired) {
            // リフレッシュトークンでアクセストークンを更新
            await refreshToken();
          } else {
            // 有効なトークンがある場合はユーザー情報を取得
            setToken(storedToken);
            await fetchUserProfile();
          }
        } catch (error) {
          console.error('Token validation error:', error);
          await refreshToken();
        }
      }
      
      setLoading(false);
    };

    initAuth();
  }, []);

  // ユーザープロフィール取得
  const fetchUserProfile = async () => {
    try {
      const response = await api.get('/api/v1/users/me');
      setUser(response.data.user);
    } catch (error) {
      console.error('Failed to fetch user profile:', error);
      setToken(null);
      setUser(null);
      localStorage.removeItem('token');
    }
  };

  // リフレッシュトークンでアクセストークンを更新
  const refreshToken = async () => {
    try {
      const response = await api.post('/api/v1/auth/refresh');
      const newToken = response.data.token;
      
      setToken(newToken);
      localStorage.setItem('token', newToken);
      setUser(response.data.user);
      return true;
    } catch (error) {
      console.error('Token refresh failed:', error);
      // リフレッシュトークンが無効な場合はログアウト状態にする
      setToken(null);
      setUser(null);
      localStorage.removeItem('token');
      return false;
    }
  };

  // ログイン処理
  const login = async (email: string, password: string) => {
    setLoading(true);
    
    try {
      const response = await api.post('/api/v1/auth/login', {
        auth: { email, password }
      });
      
      const { token: newToken, user: userData } = response.data;
      
      setToken(newToken);
      setUser(userData);
      localStorage.setItem('token', newToken);
      
      navigate('/dashboard');
    } catch (error: any) {
      console.error('Login failed:', error);
      
      // APIからのエラーメッセージを表示
      const errorMessage = error.response?.data?.error || 'ログインに失敗しました';
      throw new Error(errorMessage);
    } finally {
      setLoading(false);
    }
  };

  // 新規ユーザー登録
  const register = async (userData: RegisterData) => {
    setLoading(true);
    
    try {
      const response = await api.post('/api/v1/auth/register', {
        user: userData
      });
      
      const { token: newToken, user: newUser } = response.data;
      
      setToken(newToken);
      setUser(newUser);
      localStorage.setItem('token', newToken);
      
      navigate('/dashboard');
    } catch (error: any) {
      console.error('Registration failed:', error);
      
      // APIからのエラーメッセージを表示
      const errorMessage = error.response?.data?.error || '登録に失敗しました';
      throw new Error(errorMessage);
    } finally {
      setLoading(false);
    }
  };

  // ログアウト処理
  const logout = async () => {
    try {
      // サーバーサイドでのログアウト処理
      await api.delete('/api/v1/auth/logout');
    } catch (error) {
      console.error('Logout request failed:', error);
    } finally {
      // クライアントサイドでのログアウト処理
      setUser(null);
      setToken(null);
      localStorage.removeItem('token');
      navigate('/login');
    }
  };

  // 認証状態チェック
  const isAuthenticated = () => {
    return !!token && !!user;
  };

  return (
    <AuthContext.Provider
      value={{
        user,
        token,
        loading,
        login,
        register,
        logout,
        isAuthenticated
      }}
    >
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = (): AuthContextType => {
  const context = useContext(AuthContext);
  
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  
  return context;
};
```

#### 2. APIインターセプターの設定

`src/services/api.ts`
```tsx
import axios from 'axios';

const api = axios.create({
  baseURL: process.env.REACT_APP_API_BASE_URL || 'http://localhost:3001',
  headers: {
    'Content-Type': 'application/json'
  },
  withCredentials: true // クッキーを送信するために必要
});

// リクエストインターセプター：トークンを付与
api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('token');
    
    if (token) {
      config.headers['Authorization'] = `Bearer ${token}`;
    }
    
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// レスポンスインターセプター：トークン期限切れ時の自動更新
let isRefreshing = false;
let failedQueue: { resolve: (value: unknown) => void; reject: (reason?: any) => void }[] = [];

const processQueue = (error: any, token: string | null = null) => {
  failedQueue.forEach(prom => {
    if (error) {
      prom.reject(error);
    } else {
      prom.resolve(token);
    }
  });
  
  failedQueue = [];
};

api.interceptors.response.use(
  (response) => {
    return response;
  },
  async (error) => {
    const originalRequest = error.config;
    
    // 401エラー（認証切れ）かつ、既にリトライしていない場合
    if (error.response?.status === 401 && !originalRequest._retry) {
      if (isRefreshing) {
        // 既にリフレッシュ中の場合はキューに追加
        return new Promise((resolve, reject) => {
          failedQueue.push({ resolve, reject });
        })
          .then(token => {
            originalRequest.headers['Authorization'] = `Bearer ${token}`;
            return axios(originalRequest);
          })
          .catch(err => {
            return Promise.reject(err);
          });
      }
      
      originalRequest._retry = true;
      isRefreshing = true;
      
      // トークンリフレッシュを試行
      try {
        const response = await axios.post(
          `${api.defaults.baseURL}/api/v1/auth/refresh`,
          {},
          { withCredentials: true } // クッキーを送信
        );
        
        const { token } = response.data;
        
        if (token) {
          localStorage.setItem('token', token);
          api.defaults.headers.common['Authorization'] = `Bearer ${token}`;
          originalRequest.headers['Authorization'] = `Bearer ${token}`;
          
          // 待機中のリクエストを処理
          processQueue(null, token);
          
          return axios(originalRequest);
        }
      } catch (refreshError) {
        // リフレッシュに失敗した場合、キューを処理してエラーを伝播
        processQueue(refreshError, null);
        localStorage.removeItem('token');
        
        // 認証ページにリダイレクト
        window.location.href = '/login';
        
        return Promise.reject(refreshError);
      } finally {
        isRefreshing = false;
      }
    }
    
    return Promise.reject(error);
  }
);

export default api;
```

#### 3. ログインコンポーネント

`src/pages/Login.tsx`
```tsx
import React, { useState } from 'react';
import { useAuth } from '../contexts/AuthContext';

const Login: React.FC = () => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const { login, loading } = useAuth();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    
    try {
      await login(email, password);
    } catch (error: any) {
      setError(error.message);
    }
  };

  return (
    <div className="login-container">
      <h2>ログイン</h2>
      
      {error && <div className="error-message">{error}</div>}
      
      <form onSubmit={handleSubmit}>
        <div className="form-group">
          <label htmlFor="email">メールアドレス</label>
          <input
            type="email"
            id="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
          />
        </div>
        
        <div className="form-group">
          <label htmlFor="password">パスワード</label>
          <input
            type="password"
            id="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />
        </div>
        
        <button type="submit" disabled={loading}>
          {loading ? 'ログイン中...' : 'ログイン'}
        </button>
      </form>
    </div>
  );
};

export default Login;
```

#### 4. 認証ルートガード

`src/components/PrivateRoute.tsx`
```tsx
import React from 'react';
import { Navigate, Outlet } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';

const PrivateRoute: React.FC = () => {
  const { isAuthenticated, loading } = useAuth();

  // 認証状態のロード中
  if (loading) {
    return <div>Loading...</div>;
  }

  // 認証済みならOutlet（子ルート）を表示、未認証ならログインページにリダイレクト
  return isAuthenticated() ? <Outlet /> : <Navigate to="/login" />;
};

export default PrivateRoute;
```

#### 5. ルート設定

`src/App.tsx`
```tsx
import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { AuthProvider } from './contexts/AuthContext';
import PrivateRoute from './components/PrivateRoute';
import Login from './pages/Login';
import Register from './pages/Register';
import Dashboard from './pages/Dashboard';
import Profile from './pages/Profile';

const App: React.FC = () => {
  return (
    <Router>
      <AuthProvider>
        <Routes>
          {/* 公開ルート */}
          <Route path="/login" element={<Login />} />
          <Route path="/register" element={<Register />} />
          
          {/* 認証が必要なルート */}
          <Route element={<PrivateRoute />}>
            <Route path="/dashboard" element={<Dashboard />} />
            <Route path="/profile" element={<Profile />} />
          </Route>
          
          {/* デフォルトリダイレクト */}
          <Route path="*" element={<Navigate to="/login" replace />} />
        </Routes>
      </AuthProvider>
    </Router>
  );
};

export default App;
```

## トークン管理

### トークン保存場所

1. **アクセストークン（短期）**:
   - **LocalStorage**: シンプルで使いやすいが、XSS攻撃に弱い
   - **メモリ**: セキュアだがページ更新でリセット
   - **React状態管理**: メモリと同様だが、Reduxなどで永続化可能

2. **リフレッシュトークン（長期）**:
   - **HttpOnly Cookie**: セキュリティが高い（XSS対策）
   - **APIからのみアクセス可能**
   - **自動的にリクエストに含まれる**

### Eventa推奨アプローチ

- **アクセストークン**: 
  - メモリ内状態管理（React Context）
  - SPA内での認証状態維持にはLocalStorageも使用可能
  
- **リフレッシュトークン**:
  - HttpOnly Cookieのみ（JavaScriptからアクセス不可）
  - `withCredentials: true` でリクエスト時に自動送信

## セキュリティ考慮事項

1. **XSS（クロスサイトスクリプティング）対策**:
   - リフレッシュトークンはHttpOnly Cookieに保存
   - ReactのJSXエスケープを活用
   - ユーザー入力は常にバリデーション

2. **CSRF（クロスサイトリクエストフォージェリ）対策**:
   - JWTをAuthorizationヘッダーで送信
   - 重要な操作にはCSRFトークンも併用
   - SameSite=Lax/Strict Cookieポリシー

3. **APIセキュリティ**:
   - HTTPS通信の強制
   - CORS設定の適切な構成
   - センシティブエンドポイントでの追加認証

4. **ログアウト時の対応**:
   - すべてのトークンをクリア
   - バックエンドでのブラックリスト登録（特に重要なケース）

## テスト方法

### 認証フローのテスト（Cypress）

```javascript
// cypress/integration/auth.spec.js
describe('認証フロー', () => {
  beforeEach(() => {
    cy.visit('/');
  });

  it('有効なユーザーでログインできること', () => {
    cy.visit('/login');
    cy.get('#email').type('user@example.com');
    cy.get('#password').type('password123');
    cy.get('form').submit();

    // ダッシュボードにリダイレクトされることを確認
    cy.url().should('include', '/dashboard');
    
    // ユーザー情報が表示されることを確認
    cy.contains('Example User');
  });

  it('無効な認証情報では拒否されること', () => {
    cy.visit('/login');
    cy.get('#email').type('user@example.com');
    cy.get('#password').type('wrongpassword');
    cy.get('form').submit();

    // エラーメッセージが表示されることを確認
    cy.contains('メールアドレスまたはパスワードが正しくありません');
    
    // ログインページにとどまることを確認
    cy.url().should('include', '/login');
  });

  it('認証されていないユーザーはプライベートルートにアクセスできないこと', () => {
    // ログアウト状態でダッシュボードへのアクセスを試行
    cy.visit('/dashboard');
    
    // ログインページにリダイレクトされることを確認
    cy.url().should('include', '/login');
  });

  it('ログアウトが正常に機能すること', () => {
    // ログイン
    cy.login('user@example.com', 'password123');
    
    // ログアウトボタンをクリック
    cy.get('[data-testid="logout-button"]').click();
    
    // ログインページにリダイレクトされることを確認
    cy.url().should('include', '/login');
    
    // ダッシュボードへの再アクセスを試行
    cy.visit('/dashboard');
    
    // ログインページに再びリダイレクトされることを確認
    cy.url().should('include', '/login');
  });
});
```

## トラブルシューティング

### 一般的な問題と解決策

1. **トークン期限切れエラー**:
   - 問題: API呼び出しで401エラーが頻繁に発生
   - 解決策: リフレッシュトークンが正しく動作しているか確認、APIインターセプターを確認

2. **CORS関連エラー**:
   - 問題: ブラウザコンソールにCORSエラー
   - 解決策: バックエンドのCORS設定を確認、特に認証ヘッダーとクッキー設定

3. **クッキー問題**:
   - 問題: HttpOnlyクッキーが保存・送信されない
   - 解決策: 
     - `withCredentials: true` の設定
     - クロスオリジンの場合は適切なSameSite設定
     - 開発環境でのHTTPS設定確認

4. **リダイレクトループ**:
   - 問題: ログイン状態の検出に問題があり、リダイレクトが繰り返される
   - 解決策: 認証状態チェックロジックを見直し、無限ループを防ぐ条件を追加

5. **トークン検証エラー**:
   - 問題: 有効なトークンなのにAPI拒否される
   - 解決策: JWT形式確認、ヘッダー形式確認（Bearer空白など）、トークン内容のデバッグ 