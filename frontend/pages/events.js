import React, { useState, useEffect } from 'react';
import { useRouter } from 'next/router';
import Head from 'next/head';
import Link from 'next/link';
import { useAuth } from '../contexts/AuthContext';
import styles from '../styles/Events.module.css';
import Header from '../components/Header';

const Events = () => {
  const { isAuthenticated, loading, hasRole } = useAuth();
  const [events, setEvents] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const router = useRouter();

  // ダミーデータ
  useEffect(() => {
    // APIからイベントを取得する代わりに、ダミーデータをセット
    setTimeout(() => {
      setEvents([
        { id: 1, title: 'テクノロジーカンファレンス', date: '2025-06-15', type: 'ビジネス', description: '最新技術動向について学ぶ1日イベント' },
        { id: 2, title: '音楽フェスティバル', date: '2025-07-20', type: 'エンターテイメント', description: '地元アーティストによる野外コンサート' },
        { id: 3, title: 'チャリティマラソン', date: '2025-08-05', type: 'スポーツ', description: '環境保護のための募金イベント' }
      ]);
      setIsLoading(false);
    }, 1000);
  }, []);

  // 認証チェック
  useEffect(() => {
    if (!loading && !isAuthenticated()) {
      router.push('/login?next=/events');
    }
  }, [isAuthenticated, loading, router]);

  // ロード中の表示
  if (loading) {
    return (
      <div className={styles.loadingContainer}>
        <div className={styles.loading}>読み込み中...</div>
      </div>
    );
  }

  return (
    <>
      <Head>
        <title>イベント一覧 | Eventa</title>
        <meta name="description" content="Eventaのイベント一覧 - 開催予定のイベントをチェックしましょう" />
      </Head>

      <Header />

      <div className={styles.eventsContainer}>
        <div className={styles.pageHeader}>
          <h1 className={styles.pageTitle}>イベント一覧</h1>
          <p className={styles.pageDescription}>興味のあるイベントを見つけて参加しましょう</p>
        </div>

        {isLoading ? (
          <div className={styles.loadingContainer}>
            <div className={styles.loading}>イベントを読み込み中...</div>
          </div>
        ) : events.length > 0 ? (
          <div className={styles.eventsGrid}>
            {events.map(event => (
              <div key={event.id} className={styles.eventCard} data-testid="event-card">
                <div className={styles.eventImage}>
                  <img src={`/images/event-default.jpg`} alt={event.title} />
                </div>
                <div className={styles.eventInfo}>
                  <h2 className={styles.eventTitle}>{event.title}</h2>
                  <span className={styles.eventDate}>{event.date}</span>
                  <p className={styles.eventDescription}>{event.description}</p>
                  <div className={styles.eventFooter}>
                    <span className={styles.eventType}>{event.type}</span>
                    <Link href={`/events/${event.id}`} className={styles.eventLink}>
                      詳細を見る
                    </Link>
                  </div>
                </div>
              </div>
            ))}
          </div>
        ) : (
          <div className={styles.noEvents}>
            <h2 className={styles.noEventsTitle}>イベントが見つかりません</h2>
            <p className={styles.noEventsMessage}>現在公開されているイベントはありません。</p>
            {hasRole && hasRole('organizer') && (
              <Link href="/events/create" className={styles.createEventLink}>
                新しいイベントを作成する
              </Link>
            )}
          </div>
        )}
      </div>
    </>
  );
};

export default Events; 