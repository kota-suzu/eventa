import Link from 'next/link'
import styles from './Header.module.css'

export default function Header() {
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
          <Link href="/create" className={styles.navLink}>
            イベント作成
          </Link>
          <Link href="/about" className={styles.navLink}>
            概要
          </Link>
        </nav>
        
        <div className={styles.auth}>
          <Link href="/login" className={styles.login}>
            ログイン
          </Link>
          <Link href="/signup" className={styles.signup}>
            登録
          </Link>
        </div>
      </div>
    </header>
  )
}