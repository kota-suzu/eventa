import Head from 'next/head'
import { useEffect, useState } from 'react'
import styles from '../styles/Home.module.css'
import Header from '../components/Header'

export default function Home() {
  const [events, setEvents] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    // APIからイベント一覧を取得するサンプルコード
    // 実際のエンドポイントに合わせて調整が必要
    const fetchEvents = async () => {
      try {
        const response = await fetch('http://localhost:3001/api/events');
        if (!response.ok) {
          throw new Error('APIからのデータ取得に失敗しました');
        }
        const data = await response.json();
        setEvents(data);
        setLoading(false);
      } catch (error) {
        setError(error.message);
        setLoading(false);
      }
    };

    // APIが準備できたらコメントを外す
    // fetchEvents();
    
    // APIが準備できるまではダミーデータを使用
    setTimeout(() => {
      setEvents([
        { id: 1, title: '新製品発表会', date: '2025-01-15', location: '東京' },
        { id: 2, title: 'テックカンファレンス', date: '2025-02-20', location: '大阪' },
        { id: 3, title: 'デザインワークショップ', date: '2025-03-10', location: '京都' },
      ]);
      setLoading(false);
    }, 1000);
  }, []);

  return (
    <div className={styles.container}>
      <Head>
        <title>Eventa - イベント管理システム</title>
        <meta name="description" content="イベントの作成・管理・参加を簡単に" />
        <link rel="icon" href="/favicon.ico" />
      </Head>

      <Header />

      <main className={styles.main}>
        <h1 className={styles.title}>
          <span className={styles.highlight}>Eventa</span>へようこそ
        </h1>

        <p className={styles.description}>
          簡単にイベントを作成、管理、共有できるプラットフォーム
        </p>

        <div className={styles.grid}>
          <div className={styles.card}>
            <h2>イベントを作成 &rarr;</h2>
            <p>新しいイベントを数分で作成して、参加者を招待しましょう。</p>
          </div>

          <div className={styles.card}>
            <h2>イベントを探す &rarr;</h2>
            <p>あなたの興味に合わせたイベントを見つけて参加しましょう。</p>
          </div>
          
          <div className={styles.card}>
            <h2>管理を簡単に &rarr;</h2>
            <p>参加者の管理、出欠確認、リマインダー送信が簡単にできます。</p>
          </div>

          <div className={styles.card}>
            <h2>分析と改善 &rarr;</h2>
            <p>イベントのフィードバックを集めて、次回の改善に活かしましょう。</p>
          </div>
        </div>

        <section className={styles.eventsSection}>
          <h2 className={styles.sectionTitle}>今後のイベント</h2>
          
          {loading ? (
            <p>イベントを読み込み中...</p>
          ) : error ? (
            <p className={styles.error}>{error}</p>
          ) : (
            <div className={styles.eventList}>
              {events.map((event) => (
                <div key={event.id} className={styles.eventCard}>
                  <h3>{event.title}</h3>
                  <p>日時: {event.date}</p>
                  <p>場所: {event.location}</p>
                  <button className={styles.button}>詳細を見る</button>
                </div>
              ))}
            </div>
          )}
        </section>
      </main>

      <footer className={styles.footer}>
        <p>&copy; 2025 Eventa Team - すべての権利を保有</p>
      </footer>
    </div>
  )
} 