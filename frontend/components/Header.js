import Link from 'next/link'
import { useAuth } from '../contexts/AuthContext'
import styles from './Header.module.css'
import { useState, useEffect, useRef } from 'react'

export default function Header() {
  const { isAuthenticated, user, logout, loading } = useAuth();
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const menuRef = useRef(null);

  const toggleMenu = () => {
    setIsMenuOpen(!isMenuOpen);
  };

  // 外側クリックを検知してメニューを閉じる
  useEffect(() => {
    const handleClickOutside = (event) => {
      if (menuRef.current && !menuRef.current.contains(event.target)) {
        setIsMenuOpen(false);
      }
    };

    // mousedownイベントでキャプチャ（clickよりも先行して発生する）
    document.addEventListener('mousedown', handleClickOutside);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, []);

  return (
    <header className={styles.header}>
      <div className={styles.container}>
        <Link href="/" className={styles.logo}>
          <span className={styles.highlight}>Eventa</span>
        </Link>
        
        <nav className={styles.nav}>
          <Link href="/events" className={styles.navLink}>
            イベント一覧
          </Link>
          {isAuthenticated && user?.attributes?.role === 'organizer' && (
            <Link href="/create" className={styles.navLink}>
              イベント作成
            </Link>
          )}
          <Link href="/about" className={styles.navLink}>
            概要
          </Link>
        </nav>
        
        <div className={styles.auth}>
          {!loading && (
            <>
              {isAuthenticated ? (
                <div className={styles.userMenu} ref={menuRef}>
                  <button 
                    onClick={toggleMenu} 
                    className={styles.userButton}
                    type="button"
                  >
                    <span className={styles.username}>
                      {user?.attributes?.name}
                    </span>
                    <span className={styles.menuArrow}>▼</span>
                  </button>
                  
                  {isMenuOpen && (
                    <div className={styles.dropdown}>
                      <Link href="/dashboard" className={styles.dropdownItem}>
                        ダッシュボード
                      </Link>
                      <Link href="/profile" className={styles.dropdownItem}>
                        プロフィール編集
                      </Link>
                      <button 
                        onClick={logout} 
                        className={styles.dropdownItem}
                        type="button"
                      >
                        ログアウト
                      </button>
                    </div>
                  )}
                </div>
              ) : (
                <>
                  <Link href="/login" className={styles.login}>
                    ログイン
                  </Link>
                  <Link href="/signup" className={styles.signup}>
                    登録
                  </Link>
                </>
              )}
            </>
          )}
        </div>
      </div>
    </header>
  )
}