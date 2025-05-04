import React, { useEffect } from 'react';
import { useRouter } from 'next/router';
import Head from 'next/head';
import { useAuth } from '../contexts/AuthContext';
import Header from '../components/Header';

const Profile = () => {
  const { user, isAuthenticated, loading } = useAuth();
  const router = useRouter();

  // 認証チェック
  useEffect(() => {
    if (!loading && !isAuthenticated()) {
      router.push('/login?next=/profile');
    }
  }, [isAuthenticated, loading, router]);

  // ロード中の表示
  if (loading || !user) {
    return (
      <div style={{ textAlign: 'center', padding: '2rem' }}>
        <div>読み込み中...</div>
      </div>
    );
  }

  return (
    <>
      <Head>
        <title>プロフィール | Eventa</title>
        <meta name="description" content="Eventaのユーザープロフィール管理画面" />
      </Head>

      <Header />

      <div style={{ maxWidth: '800px', margin: '0 auto', padding: '2rem' }}>
        <h1 style={{ fontSize: '2rem', marginBottom: '1.5rem' }}>プロフィール設定</h1>

        <div
          style={{
            background: '#fff',
            padding: '2rem',
            borderRadius: '8px',
            boxShadow: '0 2px 10px rgba(0,0,0,0.1)',
          }}
        >
          <div style={{ marginBottom: '1.5rem' }}>
            <h2 style={{ fontSize: '1.5rem', marginBottom: '1rem' }}>基本情報</h2>
            <p>
              <strong>名前:</strong> {user.name}
            </p>
            <p>
              <strong>メールアドレス:</strong> {user.email}
            </p>
            <p>
              <strong>ユーザータイプ:</strong>{' '}
              {user.role === 'organizer' ? 'イベント主催者' : 'イベント参加者'}
            </p>
          </div>

          <div style={{ marginTop: '2rem' }}>
            <p style={{ color: '#666', fontSize: '0.9rem' }}>
              プロフィール編集機能は近日公開予定です。
            </p>
          </div>
        </div>
      </div>
    </>
  );
};

export default Profile;
