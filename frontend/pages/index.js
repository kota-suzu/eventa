import { useState, useEffect } from 'react';
import Head from 'next/head';
import Link from 'next/link';
import Image from 'next/image';
import styles from '../styles/Home.module.css';
import { useAuth } from '../contexts/AuthContext';
import Header from '../components/Header';

export default function Home() {
  const [events, setEvents] = useState([]);
  const [isLoading, setIsLoading] = useState(false);
  const { isAuthenticated } = useAuth();

  // 新着イベント取得（例）
  useEffect(() => {
    const fetchEvents = async () => {
      try {
        setIsLoading(true);
        // 本番ではAPIから取得
        // const response = await fetch('/api/featured-events');
        // const data = await response.json();

        // ダミーデータ
        setTimeout(() => {
          setEvents([
            { id: 1, title: '新製品発表会', imageUrl: '/images/event1.jpg' },
            { id: 2, title: 'テックカンファレンス', imageUrl: '/images/event2.jpg' },
            { id: 3, title: 'デザインワークショップ', imageUrl: '/images/event3.jpg' },
          ]);
          setIsLoading(false);
        }, 500);
      } catch (error) {
        console.error('イベント取得エラー:', error);
        setIsLoading(false);
      }
    };

    fetchEvents();
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
        {/* ヒーローセクション */}
        <section className={styles.hero}>
          <div className={styles.heroContent}>
            <h1 className={styles.title}>
              <span className={styles.highlight}>Eventa</span>へようこそ
            </h1>

            <p className={styles.description}>
              簡単にイベントを作成、管理、共有できるプラットフォーム
            </p>

            {!isAuthenticated && (
              <div className={styles.ctaContainer}>
                <h2 className={styles.ctaTitle}>今すぐEventa を始めましょう</h2>
                <div className={styles.ctaButtons}>
                  <Link href="/register" className={styles.primaryButton}>
                    無料で新規登録
                  </Link>
                  <Link href="/login" className={styles.secondaryButton}>
                    ログイン
                  </Link>
                </div>
                <p className={styles.ctaDescription}>
                  既に多くの方がEventaでイベントを管理しています
                </p>
              </div>
            )}

            {isAuthenticated && (
              <div className={styles.ctaContainer}>
                <div className={styles.ctaButtons}>
                  <Link href="/dashboard" className={styles.primaryButton}>
                    ダッシュボードへ
                  </Link>
                  <Link href="/events" className={styles.secondaryButton}>
                    イベントを探す
                  </Link>
                </div>
              </div>
            )}
          </div>

          <div className={styles.heroImage}>
            <Image
              src="/images/hero-image.svg"
              alt="イベント管理"
              width={500}
              height={350}
              priority
            />
          </div>
        </section>

        {/* 特徴セクション */}
        <section className={styles.features}>
          <h2 className={styles.sectionTitle}>Eventaの特徴</h2>
          <div className={styles.featureGrid}>
            <div className={styles.featureCard}>
              <div className={styles.featureIcon}>📅</div>
              <h3 className={styles.featureTitle}>イベントを作成</h3>
              <p className={styles.featureDescription}>
                新しいイベントを数分で作成して、参加者を招待しましょう。
              </p>
            </div>

            <div className={styles.featureCard}>
              <div className={styles.featureIcon}>🔍</div>
              <h3 className={styles.featureTitle}>イベントを探す</h3>
              <p className={styles.featureDescription}>
                あなたの興味に合わせたイベントを見つけて参加しましょう。
              </p>
            </div>

            <div className={styles.featureCard}>
              <div className={styles.featureIcon}>📊</div>
              <h3 className={styles.featureTitle}>管理を簡単に</h3>
              <p className={styles.featureDescription}>
                参加者の管理、出欠確認、リマインダー送信が簡単にできます。
              </p>
            </div>

            <div className={styles.featureCard}>
              <div className={styles.featureIcon}>📈</div>
              <h3 className={styles.featureTitle}>分析と改善</h3>
              <p className={styles.featureDescription}>
                イベントのフィードバックを集めて、次回の改善に活かしましょう。
              </p>
            </div>
          </div>
        </section>

        {/* 今後のイベント */}
        <section className={styles.upcomingEvents}>
          <h2 className={styles.sectionTitle}>今後のイベント</h2>
          {isLoading ? (
            <div className={styles.loading}>読み込み中...</div>
          ) : (
            <div className={styles.eventGrid}>
              {events.map((event) => (
                <div key={event.id} className={styles.eventCard}>
                  <div className={styles.eventImage}>
                    <Image
                      src={event.imageUrl || '/images/event-default.jpg'}
                      alt={event.title}
                      width={300}
                      height={200}
                      style={{ objectFit: 'cover' }}
                    />
                  </div>
                  <div className={styles.eventInfo}>
                    <h3 className={styles.eventTitle}>{event.title}</h3>
                    <Link href={`/events/${event.id}`} className={styles.eventLink}>
                      詳細を見る
                    </Link>
                  </div>
                </div>
              ))}
            </div>
          )}

          <div className={styles.viewAllContainer}>
            <Link href="/events" className={styles.viewAllLink}>
              すべてのイベントを見る
            </Link>
          </div>
        </section>
      </main>

      <footer className={styles.footer}>
        <div className={styles.footerContent}>
          <div className={styles.footerLogo}>Eventa</div>
          <div className={styles.footerLinks}>
            <Link href="/about" className={styles.footerLink}>
              概要
            </Link>
            <Link href="/terms" className={styles.footerLink}>
              利用規約
            </Link>
            <Link href="/privacy" className={styles.footerLink}>
              プライバシーポリシー
            </Link>
            <Link href="/contact" className={styles.footerLink}>
              お問い合わせ
            </Link>
          </div>
          <div className={styles.copyright}>
            &copy; {new Date().getFullYear()} Eventa. All rights reserved.
          </div>
        </div>
      </footer>
    </div>
  );
}
