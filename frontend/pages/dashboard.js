import React, { useState, useEffect } from 'react';
import { useRouter } from 'next/router';
import Head from 'next/head';
import Link from 'next/link';
import { useAuth } from '../contexts/AuthContext';
import styles from '../styles/Dashboard.module.css';

// TODO(!frontend): ユーザーダッシュボードの機能強化
// ダッシュボードに以下の機能を追加：
// - イベント管理（作成、編集、削除）
// - チケット購入履歴と管理
// - 収益・売上分析（主催者向け）
// - お気に入りイベント管理

// TODO(!frontend): APIからユーザー関連イベントを取得
// ユーザーが主催または参加予定のイベントをAPIから取得し、
// 直感的なカレンダービューとリスト表示で提示。

// TODO(!frontend): レスポンシブデザインの最適化
// モバイル、タブレット、デスクトップの各画面サイズに
// 最適化されたレイアウトを実装。コンポーネントの再利用性も高める。

// TODO(!frontend): ユーザー設定管理機能
// プロフィール編集、通知設定、セキュリティ設定、
// 支払い方法管理などの設定機能を追加。

// TODO(!feature): アクセシビリティ対応
// WAI-ARIAに準拠したアクセシブルなUI実装。
// キーボードナビゲーション、スクリーンリーダー対応、
// カラーコントラスト考慮などを含む。

// ダッシュボードページ
const Dashboard = () => {
  const { user, isAuthenticated, loading, hasRole } = useAuth();
  const [userEvents, setUserEvents] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);
  const router = useRouter();

  // 認証チェック
  useEffect(() => {
    if (!loading && !isAuthenticated()) {
      router.push('/login?next=/dashboard');
    }
  }, [isAuthenticated, loading, router]);

  // ユーザーイベントの取得
  useEffect(() => {
    const fetchUserEvents = async () => {
      if (!user) return;

      try {
        setIsLoading(true);
        setError(null);

        // TODO(!frontend): APIからユーザー関連イベントを取得
        // const response = await api.get('/api/v1/events/user');
        // setUserEvents(response.data);

        // ダミーデータ（本番では削除）
        setTimeout(() => {
          setUserEvents([
            {
              id: 1,
              title: '新製品発表会',
              date: '2023-12-15',
              status: 'upcoming',
              participants: 42,
            },
            {
              id: 2,
              title: 'テックカンファレンス',
              date: '2024-01-20',
              status: 'upcoming',
              participants: 120,
            },
            {
              id: 3,
              title: '社内勉強会',
              date: '2023-11-05',
              status: 'completed',
              participants: 15,
            },
          ]);
          setIsLoading(false);
        }, 500);
      } catch (err) {
        console.error('Failed to fetch user events:', err);
        setError('イベント情報の取得中にエラーが発生しました。');
        setIsLoading(false);
      }
    };

    fetchUserEvents();
  }, [user]);

  // ロード中の表示
  if (loading || !user) {
    return (
      <div className={styles.loadingContainer}>
        <div className={styles.loading}>読み込み中...</div>
      </div>
    );
  }

  return (
    <>
      <Head>
        <title>ダッシュボード | Eventa</title>
        <meta name="description" content="Eventaユーザーダッシュボード - イベントの管理と確認" />
      </Head>

      <div className={styles.dashboardContainer}>
        <div className={styles.dashboardHeader}>
          <h1 className={styles.dashboardTitle}>ダッシュボード</h1>

          <div className={styles.userInfo}>
            <div className={styles.welcomeMessage}>
              ようこそ、{user.name || user.attributes?.name || 'ユーザー'}さん
            </div>

            <div className={styles.actionButtons}>
              {hasRole('organizer') && (
                <Link href="/events/create" className={styles.createButton}>
                  新規イベント作成
                </Link>
              )}
              <Link href="/profile" className={styles.profileButton}>
                プロフィール編集
              </Link>
            </div>
          </div>
        </div>

        <div className={styles.dashboardContent}>
          <div className={styles.eventsSection}>
            <h2 className={styles.sectionTitle}>あなたのイベント</h2>

            {isLoading ? (
              <div className={styles.loading}>イベントを読み込み中...</div>
            ) : error ? (
              <div className={styles.error}>{error}</div>
            ) : userEvents.length > 0 ? (
              <div className={styles.eventsList}>
                <table className={styles.eventsTable}>
                  <thead>
                    <tr>
                      <th>イベント名</th>
                      <th>日付</th>
                      <th>ステータス</th>
                      <th>参加者</th>
                      <th>アクション</th>
                    </tr>
                  </thead>
                  <tbody>
                    {userEvents.map((event) => (
                      <tr key={event.id}>
                        <td>{event.title}</td>
                        <td>{event.date}</td>
                        <td>
                          <span className={`${styles.status} ${styles[event.status]}`}>
                            {event.status === 'upcoming' ? '予定' : '完了'}
                          </span>
                        </td>
                        <td>{event.participants}</td>
                        <td>
                          <div className={styles.actionLinks}>
                            <Link href={`/events/${event.id}`} className={styles.viewLink}>
                              詳細
                            </Link>
                            <Link href={`/events/${event.id}/edit`} className={styles.editLink}>
                              編集
                            </Link>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : (
              <div className={styles.noEvents}>
                <p>まだイベントがありません。</p>
                {hasRole('organizer') && (
                  <Link href="/events/create" className={styles.createLink}>
                    最初のイベントを作成する
                  </Link>
                )}
              </div>
            )}
          </div>

          <div className={styles.quickStats}>
            <h2 className={styles.sectionTitle}>クイック統計</h2>
            <div className={styles.statsGrid}>
              <div className={styles.statCard}>
                <div className={styles.statValue}>{userEvents.length}</div>
                <div className={styles.statLabel}>総イベント数</div>
              </div>
              <div className={styles.statCard}>
                <div className={styles.statValue}>
                  {userEvents.filter((e) => e.status === 'upcoming').length}
                </div>
                <div className={styles.statLabel}>今後のイベント</div>
              </div>
              <div className={styles.statCard}>
                <div className={styles.statValue}>
                  {userEvents.reduce((sum, event) => sum + event.participants, 0)}
                </div>
                <div className={styles.statLabel}>総参加者数</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </>
  );
};

export default Dashboard;
