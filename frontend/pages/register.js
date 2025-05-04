import React, { useState, useEffect } from 'react';
import { useRouter } from 'next/router';
import Link from 'next/link';
import styles from '../styles/Auth.module.css';
import { useAuth } from '../contexts/AuthContext';

const Register = () => {
  const [formData, setFormData] = useState({
    email: '',
    name: '',
    password: '',
    password_confirmation: '',
    role: 'guest',
    terms_accepted: false,
  });
  const [errors, setErrors] = useState({});
  const [isLoading, setIsLoading] = useState(false);
  const [serverError, setServerError] = useState('');
  const [successMessage, setSuccessMessage] = useState('');
  const [fieldTouched, setFieldTouched] = useState({});

  const router = useRouter();
  const { register } = useAuth();

  const handleChange = (e) => {
    const { name, value, type, checked } = e.target;
    const fieldValue = type === 'checkbox' ? checked : value;

    setFormData((prev) => ({
      ...prev,
      [name]: fieldValue,
    }));

    // フィールド変更時にエラーをクリア
    if (errors[name]) {
      setErrors((prev) => ({
        ...prev,
        [name]: '',
      }));
    }

    // フィールドがタッチされたことを記録
    if (!fieldTouched[name]) {
      setFieldTouched((prev) => ({
        ...prev,
        [name]: true,
      }));
    }

    // リアルタイムバリデーション
    validateField(name, fieldValue);
  };

  // 単一フィールドの検証
  const validateField = (name, value) => {
    let errorMessage = '';

    switch (name) {
      case 'email':
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!value) {
          errorMessage = 'メールアドレスは必須です';
        } else if (!emailRegex.test(value)) {
          errorMessage = '有効なメールアドレスを入力してください';
        }
        break;

      case 'name':
        if (!value) {
          errorMessage = '氏名は必須です';
        } else if (value.length > 50) {
          errorMessage = '氏名は50文字以内で入力してください';
        }
        break;

      case 'password':
        if (!value) {
          errorMessage = 'パスワードは必須です';
        } else if (value.length < 8) {
          errorMessage = 'パスワードは8文字以上にしてください';
        } else if (value.length > 72) {
          errorMessage = 'パスワードは72文字以内で入力してください';
        }

        // パスワード変更時に確認フィールドも検証
        if (formData.password_confirmation && value !== formData.password_confirmation) {
          setErrors((prev) => ({
            ...prev,
            password_confirmation: 'パスワードが一致しません',
          }));
        } else if (formData.password_confirmation) {
          setErrors((prev) => {
            const newErrors = { ...prev };
            delete newErrors.password_confirmation;
            return newErrors;
          });
        }
        break;

      case 'password_confirmation':
        if (formData.password && value !== formData.password) {
          errorMessage = 'パスワードが一致しません';
        }
        break;

      case 'terms_accepted':
        if (!value) {
          errorMessage = '利用規約に同意する必要があります';
        }
        break;

      default:
        break;
    }

    // エラーを更新
    if (errorMessage) {
      setErrors((prev) => ({
        ...prev,
        [name]: errorMessage,
      }));
    } else {
      setErrors((prev) => {
        const newErrors = { ...prev };
        delete newErrors[name];
        return newErrors;
      });
    }

    return !errorMessage;
  };

  const validateForm = () => {
    // 全フィールドを検証
    let isValid = true;
    const newErrors = {};

    // メールアドレス
    if (!validateField('email', formData.email)) {
      isValid = false;
      newErrors.email = errors.email;
    }

    // 名前
    if (!validateField('name', formData.name)) {
      isValid = false;
      newErrors.name = errors.name;
    }

    // パスワード
    if (!validateField('password', formData.password)) {
      isValid = false;
      newErrors.password = errors.password;
    }

    // パスワード確認
    if (!validateField('password_confirmation', formData.password_confirmation)) {
      isValid = false;
      newErrors.password_confirmation = errors.password_confirmation;
    }

    // 利用規約
    if (!validateField('terms_accepted', formData.terms_accepted)) {
      isValid = false;
      newErrors.terms_accepted = errors.terms_accepted;
    }

    setErrors(newErrors);
    return isValid;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setServerError('');
    setSuccessMessage('');

    // すべてのフィールドがタッチされたとマーク
    const allTouched = Object.keys(formData).reduce((acc, key) => {
      acc[key] = true;
      return acc;
    }, {});
    setFieldTouched(allTouched);

    // フォーム検証
    if (!validateForm()) {
      return;
    }

    setIsLoading(true);

    try {
      const result = await register({
        user: {
          email: formData.email,
          name: formData.name,
          password: formData.password,
          password_confirmation: formData.password_confirmation,
          role: formData.role,
        },
      });

      if (result.ok) {
        // デバッグログ追加
        console.log('登録成功:', result.user);
        setSuccessMessage('登録が完了しました！リダイレクトします...');

        // 成功メッセージを表示してから遷移
        setTimeout(() => {
          console.log('リダイレクト開始...', formData.role);
          // すべてのロールで統一して /dashboard にリダイレクト
          router.push('/dashboard');
        }, 1500);
      } else {
        console.error('登録失敗:', result.message);
        setServerError(result.message);
      }
    } catch (err) {
      console.error('Registration error:', err);
      setServerError('登録処理中にエラーが発生しました。時間をおいて再度お試しください。');
    } finally {
      setIsLoading(false);
    }
  };

  const getPasswordStrength = () => {
    const { password } = formData;
    if (!password) return '';

    // パスワード強度の計算（簡易版）
    let strength = 0;
    if (password.length >= 8) strength += 1;
    if (password.length >= 12) strength += 1;
    if (/[A-Z]/.test(password)) strength += 1;
    if (/[a-z]/.test(password)) strength += 1;
    if (/[0-9]/.test(password)) strength += 1;
    if (/[^A-Za-z0-9]/.test(password)) strength += 1;

    if (strength < 3) return 'weak';
    if (strength < 5) return 'medium';
    return 'strong';
  };

  // パスワード強度の視覚表示の改善
  const renderPasswordStrengthMeter = () => {
    const strength = getPasswordStrength();
    if (!strength) return null;

    const percent = {
      weak: 33,
      medium: 66,
      strong: 100,
    }[strength];

    const label = {
      weak: '弱',
      medium: '中',
      strong: '強',
    }[strength];

    const tips = {
      weak: '大文字、小文字、数字、特殊文字を含めてください',
      medium: 'より強力にするには長さを増やすか、特殊文字を追加してください',
      strong: '強力なパスワードです！',
    }[strength];

    return (
      <div className={styles.passwordMeterContainer}>
        <div
          className={`${styles.passwordMeter} ${styles[strength]}`}
          style={{ width: `${percent}%` }}
        />
        <div
          className={`${styles.passwordStrengthText} ${styles[`text${strength.charAt(0).toUpperCase() + strength.slice(1)}`]}`}
        >
          パスワード強度: {label} - {tips}
        </div>
      </div>
    );
  };

  // フィールドヘルパー
  const getFieldClassName = (fieldName) => {
    const hasError = errors[fieldName] && fieldTouched[fieldName];
    return `${styles.input} ${hasError ? styles.inputError : ''}`;
  };

  return (
    <div className={styles.authContainer}>
      <div className={styles.formContainer}>
        <h1 className={styles.title}>新規登録</h1>

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
              onBlur={() => setFieldTouched((prev) => ({ ...prev, email: true }))}
            />
            {errors.email && fieldTouched.email && (
              <div className={styles.errorMessage}>{errors.email}</div>
            )}
          </div>

          <div className={styles.formGroup}>
            <label htmlFor="name">氏名</label>
            <input
              id="name"
              name="name"
              type="text"
              value={formData.name}
              onChange={handleChange}
              className={getFieldClassName('name')}
              onBlur={() => setFieldTouched((prev) => ({ ...prev, name: true }))}
            />
            {errors.name && fieldTouched.name && (
              <div className={styles.errorMessage}>{errors.name}</div>
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
              onBlur={() => setFieldTouched((prev) => ({ ...prev, password: true }))}
            />
            {formData.password && renderPasswordStrengthMeter()}
            {errors.password && fieldTouched.password && (
              <div className={styles.errorMessage}>{errors.password}</div>
            )}
          </div>

          <div className={styles.formGroup}>
            <label htmlFor="password_confirmation">パスワード確認</label>
            <input
              id="password_confirmation"
              name="password_confirmation"
              type="password"
              value={formData.password_confirmation}
              onChange={handleChange}
              className={getFieldClassName('password_confirmation')}
              onBlur={() => setFieldTouched((prev) => ({ ...prev, password_confirmation: true }))}
            />
            {errors.password_confirmation && fieldTouched.password_confirmation && (
              <div className={styles.errorMessage}>{errors.password_confirmation}</div>
            )}
          </div>

          <div className={styles.formGroup}>
            <label>ユーザータイプ</label>
            <div className={styles.radioGroup}>
              <label className={styles.radioLabel}>
                <input
                  type="radio"
                  name="role"
                  value="guest"
                  checked={formData.role === 'guest'}
                  onChange={handleChange}
                />{' '}
                イベント参加者
              </label>
              <label className={styles.radioLabel}>
                <input
                  type="radio"
                  name="role"
                  value="organizer"
                  checked={formData.role === 'organizer'}
                  onChange={handleChange}
                />{' '}
                イベント主催者
              </label>
            </div>
          </div>

          <div className={styles.formGroup}>
            <label className={styles.checkboxLabel}>
              <input
                type="checkbox"
                name="terms_accepted"
                checked={formData.terms_accepted}
                onChange={handleChange}
                onBlur={() => setFieldTouched((prev) => ({ ...prev, terms_accepted: true }))}
              />
              <span>利用規約とプライバシーポリシーに同意します</span>
            </label>
            {errors.terms_accepted && fieldTouched.terms_accepted && (
              <div className={styles.errorMessage}>{errors.terms_accepted}</div>
            )}
          </div>

          <button type="submit" className={styles.button} disabled={isLoading}>
            {isLoading ? '処理中...' : '登録する'}
          </button>
        </form>

        <div className={styles.links}>
          すでにアカウントをお持ちの方は{' '}
          <Link href="/login" className={styles.link}>
            ログイン
          </Link>
        </div>
      </div>
    </div>
  );
};

export default Register;
