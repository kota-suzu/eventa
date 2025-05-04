import React, { useEffect, useState } from 'react';
import { useRouter } from 'next/router';
import Head from 'next/head';
import Link from 'next/link';
import { useAuth } from '../../contexts/AuthContext';
import Header from '../../components/Header';

const EventDetail = () => {
  const { isAuthenticated, loading } = useAuth();
  const [event, setEvent] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const router = useRouter();
  const { id } = router.query;

  // 認証チェック
  useEffect(() => {
    if (!loading && !isAuthenticated()) {
      router.push(`/login?next=/events/${id}`);
    }
  }, [isAuthenticated, loading, router, id]);

  // イベント詳細取得
  useEffect(() => {
    // クエリパラメータが準備できたら実行
    if (id) {
      // 本番ではAPIから取得
      // const fetchEvent = async () => {
      //   const response = await fetch(`/api/events/${id}`);
      //   const data = await response.json();
      //   setEvent(data);
      //   setIsLoading(false);
      // };
      // fetchEvent();

      // ダミーデータ
      setTimeout(() => {
        setEvent({
          id,
          title: 'イベントサンプル',
          date: '2025-06-15',
          description: 'これはサンプルイベントの詳細説明です。本番環境では実際のイベント情報が表示されます。',
          location: '東京都渋谷区',
          organizer: 'サンプル主催者',
          capacity: 100,
          participants: 45
        });
        setIsLoading(false);
      }, 1000);
    }
  }, [id]);

  // ロード中の表示
  if (loading || isLoading) {
    return (
      <div style={{ textAlign: 'center', padding: '3rem' }}>
        <div>読み込み中...</div>
      </div>
    );
  }

  // イベントが見つからない
  if (!event) {
    return (
      <>
        <Header />
        <div style={{ textAlign: 'center', padding: '3rem' }}>
          <h1>イベントが見つかりません</h1>
          <p>お探しのイベントは存在しないか、削除された可能性があります。</p>
          <Link href="/events" style={{ color: '#4a6cf7', textDecoration: 'none' }}>
            イベント一覧に戻る
          </Link>
        </div>
      </>
    );
  }

  return (
    <>
      <Head>
        <title>{event.title} | Eventa</title>
        <meta name="description" content={`${event.title}の詳細情報 - ${event.description?.slice(0, 100)}...`} />
      </Head>

      <Header />

      <div style={{ maxWidth: '1000px', margin: '0 auto', padding: '2rem' }}>
        <div style={{ marginBottom: '1rem' }}>
          <Link href="/events" style={{ color: '#4a6cf7', textDecoration: 'none' }}>
            ← イベント一覧に戻る
          </Link>
        </div>

        <h1 style={{ fontSize: '2rem', marginBottom: '1rem' }}>{event.title}</h1>
        
        <div style={{ display: 'flex', gap: '1rem', marginBottom: '2rem', flexWrap: 'wrap' }}>
          <div style={{ 
            flex: '1 1 60%', 
            backgroundColor: 'white', 
            borderRadius: '8px', 
            padding: '1.5rem',
            boxShadow: '0 2px 10px rgba(0, 0, 0, 0.05)'
          }}>
            <h2 style={{ fontSize: '1.5rem', marginBottom: '1rem' }}>イベント詳細</h2>
            <p style={{ marginBottom: '1.5rem', lineHeight: '1.6' }}>{event.description}</p>
            
            <div style={{ marginTop: '2rem' }}>
              <button style={{
                backgroundColor: '#4a6cf7',
                color: 'white',
                border: 'none',
                padding: '0.75rem 1.5rem',
                borderRadius: '4px',
                cursor: 'pointer',
                fontSize: '1rem'
              }}>
                参加申し込み
              </button>
            </div>
          </div>
          
          <div style={{ 
            flex: '1 1 30%', 
            backgroundColor: 'white', 
            borderRadius: '8px', 
            padding: '1.5rem',
            boxShadow: '0 2px 10px rgba(0, 0, 0, 0.05)'
          }}>
            <h2 style={{ fontSize: '1.25rem', marginBottom: '1rem' }}>開催情報</h2>
            
            <div style={{ marginBottom: '1rem' }}>
              <div style={{ fontWeight: 'bold', marginBottom: '0.25rem' }}>日時</div>
              <div>{event.date}</div>
            </div>
            
            <div style={{ marginBottom: '1rem' }}>
              <div style={{ fontWeight: 'bold', marginBottom: '0.25rem' }}>場所</div>
              <div>{event.location}</div>
            </div>
            
            <div style={{ marginBottom: '1rem' }}>
              <div style={{ fontWeight: 'bold', marginBottom: '0.25rem' }}>主催者</div>
              <div>{event.organizer}</div>
            </div>
            
            <div style={{ marginBottom: '1rem' }}>
              <div style={{ fontWeight: 'bold', marginBottom: '0.25rem' }}>定員</div>
              <div>{event.capacity}人</div>
            </div>
            
            <div style={{ marginBottom: '1rem' }}>
              <div style={{ fontWeight: 'bold', marginBottom: '0.25rem' }}>参加状況</div>
              <div>{event.participants} / {event.capacity}</div>
              <div style={{ 
                width: '100%', 
                height: '6px', 
                backgroundColor: '#f0f0f0', 
                borderRadius: '3px',
                marginTop: '0.5rem'
              }}>
                <div style={{ 
                  width: `${(event.participants / event.capacity) * 100}%`, 
                  height: '100%', 
                  backgroundColor: '#4a6cf7', 
                  borderRadius: '3px'
                }}/>
              </div>
            </div>
          </div>
        </div>
      </div>
    </>
  );
};

export default EventDetail; 