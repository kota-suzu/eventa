import React, { useState, useEffect } from 'react';
import { useRouter } from 'next/router';
import Link from 'next/link';
import styles from '../styles/Auth.module.css';
import { useAuth } from '../contexts/AuthContext';
import Head from 'next/head';

const Login = () => {
  const [formData, setFormData] = useState({
    email: '',
    password: '',
    remember: false,
  });
  const [errors, setErrors] = useState({});
  const [isLoading, setIsLoading] = useState(false);
  const [serverError, setServerError] = useState('');
  const [successMessage, setSuccessMessage] = useState('');

  const router = useRouter();
  const { login, isAuthenticated } = useAuth();
  const { next } = router.query; // リダイレクト用パラメータ

  // 既にログイン済みなら指定されたURLまたはトップページへリダイレクト
  useEffect(() => {
    if (isAuthenticated()) {
      const redirectTo = next && next.startsWith('/') ? next : '/';
      router.push(redirectTo);
    }
  }, [isAuthenticated, router, next]);

  const handleChange = (e) => {
    const { name, value, type, checked } = e.target;
    const fieldValue = type === 'checkbox' ? checked : value;

    setFormData((prev) => ({
      ...prev,
      [name]: fieldValue,
    }));

    // エラーをクリア
    if (errors[name]) {
      setErrors((prev) => ({
        ...prev,
        [name]: '',
      }));
    }
  };

  const validateForm = () => {
    const newErrors = {};

    if (!formData.email) {
      newErrors.email = 'メールアドレスを入力してください';
    } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(formData.email)) {
      newErrors.email = '有効なメールアドレスを入力してください';
    }

    if (!formData.password) {
      newErrors.password = 'パスワードを入力してください';
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();

    // フォームをリセット
    setServerError('');
    setSuccessMessage('');

    // バリデーション
    if (!validateForm()) {
      return;
    }

    setIsLoading(true);

    try {
      const result = await login(formData.email, formData.password, formData.remember);

      if (result.ok) {
        setSuccessMessage('ログインに成功しました！リダイレクトします...');

        // 成功メッセージを表示してから遷移
        setTimeout(() => {
          // nextパラメータがあれば、そこへリダイレクト
          const redirectTo = next && next.startsWith('/') ? next : '/';
          router.push(redirectTo);
        }, 1000);
      } else {
        setServerError(result.message);
      }
    } catch (err) {
      console.error('Login error:', err);
      setServerError('ログイン処理中にエラーが発生しました。時間をおいて再度お試しください。');
    } finally {
      setIsLoading(false);
    }
  };

  // フィールドのスタイルを動的に設定（エラー時は赤枠など）
  const getFieldClassName = (fieldName) => {
    return `${styles.input} ${errors[fieldName] ? styles.inputError : ''}`;
  };

  return (
    <>
      <Head>
        <title>ログイン | Eventa</title>
        <meta name="description" content="イベント管理システムEventaへのログインページです。" />
      </Head>

      <div className={styles.authContainer}>
        <div className={styles.formContainer}>
          <h1 className={styles.title}>ログイン</h1>

          {serverError && <div className={styles.error}>{serverError}</div>}
          {successMessage && <div className={styles.success}>{successMessage}</div>}

          <form onSubmit={handleSubmit} className={styles.form}>
            <div className={styles.formGroup}>
              <label htmlFor="email">メールアドレス</label>
              <input
                id="email"
                name="email"
                type="email"
                value={formData.email}
                onChange={handleChange}
                className={getFieldClassName('email')}
                autoComplete="email"
                aria-describedby={errors.email ? 'email-error' : undefined}
              />
              {errors.email && (
                <div id="email-error" className={styles.errorMessage}>
                  {errors.email}
                </div>
              )}
            </div>

            <div className={styles.formGroup}>
              <label htmlFor="password">パスワード</label>
              <input
                id="password"
                name="password"
                type="password"
                value={formData.password}
                onChange={handleChange}
                className={getFieldClassName('password')}
                autoComplete="current-password"
                aria-describedby={errors.password ? 'password-error' : undefined}
              />
              {errors.password && (
                <div id="password-error" className={styles.errorMessage}>
                  {errors.password}
                </div>
              )}
            </div>

            <div className={styles.formGroup}>
              <label className={styles.checkboxLabel}>
                <input
                  type="checkbox"
                  name="remember"
                  checked={formData.remember}
                  onChange={handleChange}
                />
                <span>ログイン状態を保持する</span>
              </label>
            </div>

            <button type="submit" className={styles.button} disabled={isLoading}>
              {isLoading ? 'ログイン中...' : 'ログイン'}
            </button>
          </form>

          <div className={styles.links}>
            <p>
              アカウントをお持ちでないですか？{' '}
              <Link href="/register" className={styles.link}>
                新規登録
              </Link>
            </p>
            <p>
              <Link href="/forgot-password" className={styles.link}>
                パスワードをお忘れですか？
              </Link>
            </p>
          </div>
        </div>
      </div>
    </>
  );
};

export default Login;
