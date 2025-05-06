import { useState, useEffect, useMemo } from 'react';
import { testApiConnection, api as authApi } from '../utils/auth';
import apiClient from '../utils/api';
import { useAuth } from '../contexts/AuthContext';

const DebugPage = () => {
  const [result, setResult] = useState(null);
  const [loading, setLoading] = useState(false);
  const [testUserData, setTestUserData] = useState({
    name: 'テストユーザー',
    email: 'test_debug@example.com',
    password: 'password123',
    password_confirmation: 'password123',
  });
  const [useAbsolutePath, setUseAbsolutePath] = useState(false);
  const [customEndpoint, setCustomEndpoint] = useState('healthz');
  const [selectedApiClient, setSelectedApiClient] = useState('auth'); // 'auth' または 'api'
  const { register } = useAuth();

  // 選択されたAPIクライアント
  const api = selectedApiClient === 'auth' ? authApi : apiClient;

  // API設定情報
  const apiConfig = useMemo(
    () => ({
      auth: {
        baseURL: authApi.defaults.baseURL,
        withCredentials: authApi.defaults.withCredentials,
        headers: authApi.defaults.headers,
      },
      api: {
        baseURL: apiClient.defaults.baseURL,
        withCredentials: apiClient.defaults.withCredentials,
        headers: apiClient.defaults.headers,
      },
      envVars: {
        NEXT_PUBLIC_API_URL: process.env.NEXT_PUBLIC_API_URL || '未設定',
        NODE_ENV: process.env.NODE_ENV || '未設定',
      },
    }),
    []
  ); // 空の依存配列で一度だけ生成

  // APIの設定情報を表示
  useEffect(() => {
    console.log('デバッグページ - API設定情報:', apiConfig);
    console.log('現在選択中のAPIクライアント:', selectedApiClient);
  }, [selectedApiClient, apiConfig]);

  // API接続テスト
  const runConnectionTest = async () => {
    setLoading(true);
    try {
      const testResult = await testApiConnection();
      setResult({
        type: 'connection',
        data: testResult,
      });
    } catch (error) {
      setResult({
        type: 'connection',
        error: error.message,
      });
    } finally {
      setLoading(false);
    }
  };

  // エンドポイントURLを生成
  const getEndpointUrl = (endpoint) => {
    if (useAbsolutePath) {
      // 絶対パスを使用
      return `${apiConfig[selectedApiClient].baseURL}/${endpoint}`.replace(/\/+/g, '/');
    } else {
      // 相対パスを使用
      return endpoint;
    }
  };

  // 直接APIリクエスト
  const sendDirectRequest = async () => {
    setLoading(true);
    try {
      const endpoint = useAbsolutePath
        ? `${apiConfig[selectedApiClient].baseURL}/auths/register`.replace(/\/+/g, '/')
        : `${api.defaults.baseURL}/auths/register`.replace(/\/+/g, '/');

      console.log(`Fetch APIリクエスト送信先: ${endpoint}`);

      // Direct fetch without axios
      const directResponse = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ user: testUserData }),
        credentials: 'include',
      });

      let responseData;
      try {
        responseData = await directResponse.json();
      } catch (e) {
        responseData = { error: 'JSONデータの解析に失敗しました' };
      }

      setResult({
        type: 'direct',
        status: directResponse.status,
        ok: directResponse.ok,
        data: responseData,
        requestUrl: endpoint,
      });
    } catch (error) {
      setResult({
        type: 'direct',
        error: error.message,
      });
    } finally {
      setLoading(false);
    }
  };

  // AuthContext経由でリクエスト
  const sendContextRequest = async () => {
    setLoading(true);
    try {
      const registerResult = await register({ user: testUserData });
      setResult({
        type: 'context',
        data: registerResult,
      });
    } catch (error) {
      setResult({
        type: 'context',
        error: error.message,
      });
    } finally {
      setLoading(false);
    }
  };

  // Axiosを直接使用
  const sendAxiosRequest = async () => {
    setLoading(true);
    try {
      const endpoint = useAbsolutePath ? 'auths/register' : getEndpointUrl('auths/register');

      console.log(
        `Axios APIリクエスト送信先: ${useAbsolutePath ? api.defaults.baseURL + '/' + endpoint : endpoint}`
      );

      const axiosResponse = await api.post(endpoint, { user: testUserData });
      setResult({
        type: 'axios',
        status: axiosResponse.status,
        data: axiosResponse.data,
        requestUrl: useAbsolutePath ? `${api.defaults.baseURL}/${endpoint}` : endpoint,
      });
    } catch (error) {
      setResult({
        type: 'axios',
        error: error.message,
        details: error.response?.data || '詳細なし',
        requestConfig: error.config
          ? {
              url: error.config.url,
              baseURL: error.config.baseURL,
              method: error.config.method,
            }
          : '設定なし',
      });
    } finally {
      setLoading(false);
    }
  };

  // カスタムエンドポイントへのリクエスト
  const sendCustomRequest = async () => {
    setLoading(true);
    try {
      const endpoint = getEndpointUrl(customEndpoint);
      console.log(
        `カスタムリクエスト送信先(${selectedApiClient}): ${useAbsolutePath ? endpoint : api.defaults.baseURL + '/' + endpoint}`
      );

      const axiosResponse = await api.get(endpoint);
      setResult({
        type: 'custom',
        status: axiosResponse.status,
        data: axiosResponse.data,
        requestUrl: useAbsolutePath ? endpoint : `${api.defaults.baseURL}/${endpoint}`,
        apiClient: selectedApiClient,
      });
    } catch (error) {
      setResult({
        type: 'custom',
        error: error.message,
        apiClient: selectedApiClient,
        details: error.response?.data || '詳細なし',
        requestConfig: error.config
          ? {
              url: error.config.url,
              baseURL: error.config.baseURL,
              method: error.config.method,
            }
          : '設定なし',
      });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ padding: '20px', maxWidth: '800px', margin: '0 auto' }}>
      <h1>API接続デバッグ</h1>

      <div
        style={{
          marginBottom: '20px',
          padding: '15px',
          backgroundColor: '#f8f9fa',
          borderRadius: '4px',
        }}
      >
        <h2>環境変数とAPI設定</h2>
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <tbody>
            <tr>
              <td style={{ padding: '8px', borderBottom: '1px solid #ddd' }}>
                <strong>環境変数</strong>
              </td>
              <td style={{ padding: '8px', borderBottom: '1px solid #ddd' }}>
                {apiConfig.envVars.NEXT_PUBLIC_API_URL}
              </td>
            </tr>
            <tr>
              <td style={{ padding: '8px', borderBottom: '1px solid #ddd' }}>
                <strong>実行環境</strong>
              </td>
              <td style={{ padding: '8px', borderBottom: '1px solid #ddd' }}>
                {apiConfig.envVars.NODE_ENV}
              </td>
            </tr>
            <tr>
              <td style={{ padding: '8px', borderBottom: '1px solid #ddd' }}>
                <strong>auth.js ベースURL</strong>
              </td>
              <td style={{ padding: '8px', borderBottom: '1px solid #ddd' }}>
                {apiConfig.auth.baseURL}
              </td>
            </tr>
            <tr>
              <td style={{ padding: '8px', borderBottom: '1px solid #ddd' }}>
                <strong>api.js ベースURL</strong>
              </td>
              <td style={{ padding: '8px', borderBottom: '1px solid #ddd' }}>
                {apiConfig.api.baseURL}
              </td>
            </tr>
            <tr>
              <td style={{ padding: '8px', borderBottom: '1px solid #ddd' }}>
                <strong>Credentials</strong>
              </td>
              <td style={{ padding: '8px', borderBottom: '1px solid #ddd' }}>
                auth.js: {apiConfig.auth.withCredentials ? 'true' : 'false'}, api.js:{' '}
                {apiConfig.api.withCredentials ? 'true' : 'false'}
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div
        style={{
          marginBottom: '20px',
          padding: '15px',
          backgroundColor: '#e3f2fd',
          borderRadius: '4px',
        }}
      >
        <h2>API設定オプション</h2>
        <div style={{ display: 'flex', alignItems: 'center', gap: '20px', flexWrap: 'wrap' }}>
          <div>
            <label style={{ marginRight: '10px' }}>APIクライアント:</label>
            <select
              value={selectedApiClient}
              onChange={(e) => setSelectedApiClient(e.target.value)}
              style={{ padding: '5px', borderRadius: '4px' }}
            >
              <option value="auth">auth.js</option>
              <option value="api">api.js</option>
            </select>
          </div>

          <label>
            <input
              type="checkbox"
              checked={useAbsolutePath}
              onChange={(e) => setUseAbsolutePath(e.target.checked)}
            />
            絶対パスを使用
          </label>

          <div>
            <label>カスタムエンドポイント: </label>
            <input
              type="text"
              value={customEndpoint}
              onChange={(e) => setCustomEndpoint(e.target.value)}
              style={{ width: '200px', padding: '5px' }}
            />
            <button
              onClick={sendCustomRequest}
              disabled={loading}
              style={{
                marginLeft: '10px',
                padding: '5px 10px',
                background: '#17a2b8',
                color: 'white',
                border: 'none',
                borderRadius: '4px',
              }}
            >
              リクエスト送信
            </button>
          </div>
        </div>
      </div>

      <div style={{ marginBottom: '20px' }}>
        <h2>テストユーザーデータ</h2>
        <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
          <div>
            <label>名前: </label>
            <input
              type="text"
              value={testUserData.name}
              onChange={(e) => setTestUserData({ ...testUserData, name: e.target.value })}
              style={{ marginLeft: '10px', width: '300px', padding: '5px' }}
            />
          </div>
          <div>
            <label>メールアドレス: </label>
            <input
              type="email"
              value={testUserData.email}
              onChange={(e) => setTestUserData({ ...testUserData, email: e.target.value })}
              style={{ marginLeft: '10px', width: '300px', padding: '5px' }}
            />
          </div>
          <div>
            <label>パスワード: </label>
            <input
              type="password"
              value={testUserData.password}
              onChange={(e) =>
                setTestUserData({
                  ...testUserData,
                  password: e.target.value,
                  password_confirmation: e.target.value,
                })
              }
              style={{ marginLeft: '10px', width: '300px', padding: '5px' }}
            />
          </div>
        </div>
      </div>

      <div style={{ display: 'flex', gap: '10px', marginBottom: '20px', flexWrap: 'wrap' }}>
        <button
          onClick={runConnectionTest}
          disabled={loading}
          style={{
            padding: '10px',
            background: '#007bff',
            color: 'white',
            border: 'none',
            borderRadius: '4px',
          }}
        >
          API接続テスト
        </button>

        <button
          onClick={sendDirectRequest}
          disabled={loading}
          style={{
            padding: '10px',
            background: '#28a745',
            color: 'white',
            border: 'none',
            borderRadius: '4px',
          }}
        >
          直接Fetch送信
        </button>

        <button
          onClick={sendContextRequest}
          disabled={loading}
          style={{
            padding: '10px',
            background: '#dc3545',
            color: 'white',
            border: 'none',
            borderRadius: '4px',
          }}
        >
          Context経由送信
        </button>

        <button
          onClick={sendAxiosRequest}
          disabled={loading}
          style={{
            padding: '10px',
            background: '#6c757d',
            color: 'white',
            border: 'none',
            borderRadius: '4px',
          }}
        >
          Axios直接送信({selectedApiClient})
        </button>
      </div>

      {loading && (
        <div
          style={{
            padding: '20px',
            textAlign: 'center',
            backgroundColor: '#f8f9fa',
            borderRadius: '4px',
          }}
        >
          読み込み中...
        </div>
      )}

      {result && (
        <div
          style={{
            marginTop: '20px',
            padding: '15px',
            backgroundColor: '#f8f9fa',
            borderRadius: '4px',
          }}
        >
          <h2>
            結果 ({result.type} {result.apiClient ? `- ${result.apiClient}` : ''})
          </h2>
          {result.error ? (
            <div style={{ color: 'red' }}>
              <h3>エラー</h3>
              <pre
                style={{
                  backgroundColor: '#ffebee',
                  padding: '10px',
                  borderRadius: '4px',
                  overflowX: 'auto',
                }}
              >
                {result.error}
              </pre>
              {result.details && (
                <div>
                  <h4>詳細</h4>
                  <pre
                    style={{
                      backgroundColor: '#f5f5f5',
                      padding: '10px',
                      borderRadius: '4px',
                      overflowX: 'auto',
                    }}
                  >
                    {JSON.stringify(result.details, null, 2)}
                  </pre>
                </div>
              )}
              {result.requestConfig && (
                <div>
                  <h4>リクエスト設定</h4>
                  <pre
                    style={{
                      backgroundColor: '#f5f5f5',
                      padding: '10px',
                      borderRadius: '4px',
                      overflowX: 'auto',
                    }}
                  >
                    {JSON.stringify(result.requestConfig, null, 2)}
                  </pre>
                </div>
              )}
            </div>
          ) : (
            <div>
              {result.status && (
                <div>
                  <strong>ステータス:</strong> {result.status}
                </div>
              )}
              {result.ok !== undefined && (
                <div>
                  <strong>成功:</strong> {result.ok ? 'はい' : 'いいえ'}
                </div>
              )}
              {result.requestUrl && (
                <div>
                  <strong>リクエストURL:</strong> {result.requestUrl}
                </div>
              )}
              <pre
                style={{
                  backgroundColor: '#e8f5e9',
                  padding: '10px',
                  borderRadius: '4px',
                  marginTop: '10px',
                  overflowX: 'auto',
                }}
              >
                {JSON.stringify(result.data, null, 2)}
              </pre>
            </div>
          )}
        </div>
      )}

      <div
        style={{
          marginTop: '40px',
          backgroundColor: '#e3f2fd',
          padding: '15px',
          borderRadius: '4px',
        }}
      >
        <h3>デバッグのヒント</h3>
        <ul>
          <li>
            <strong>ネットワークエラー</strong>:
            APIサーバーへの接続ができていない可能性があります。CORSの設定やネットワーク接続を確認してください。
          </li>
          <li>
            <strong>CORS問題</strong>: API側で適切なCORS設定（origins, credentials）が必要です。
          </li>
          <li>
            <strong>パス問題</strong>:
            ベースURLとエンドポイントの結合で重複や不足がないか確認してください。
          </li>
          <li>
            <strong>Dockerコンテナ間接続</strong>:
            コンテナ内からの接続とブラウザからの接続はURLが異なる場合があります。
          </li>
          <li>
            <strong>環境変数</strong>:
            NEXT_PUBLIC_API_URLが正しく設定されていることを確認してください。
          </li>
          <li>
            <strong>APIクライアント重複</strong>:
            auth.jsとapi.jsの両方にAPIクライアントが定義されています。どちらを使うかを切り替えて試してください。
          </li>
        </ul>
      </div>
    </div>
  );
};

export default DebugPage;
