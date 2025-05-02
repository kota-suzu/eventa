import React, { useState } from 'react';
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
  
  const router = useRouter();
  const { register } = useAuth();
  
  const handleChange = (e) => {
    const { name, value, type, checked } = e.target;
    const fieldValue = type === 'checkbox' ? checked : value;
    
    setFormData((prev) => ({
      ...prev,
      [name]: fieldValue
    }));
    
    // フィールド変更時にエラーをクリア
    if (errors[name]) {
      setErrors((prev) => ({
        ...prev,
        [name]: ''
      }));
    }
  };
  
  const validateForm = () => {
    const newErrors = {};
    
    // メールアドレスチェック
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!formData.email) {
      newErrors.email = 'メールアドレスは必須です';
    } else if (!emailRegex.test(formData.email)) {
      newErrors.email = '有効なメールアドレスを入力してください';
    }
    
    // 名前チェック
    if (!formData.name) {
      newErrors.name = '氏名は必須です';
    } else if (formData.name.length > 50) {
      newErrors.name = '氏名は50文字以内で入力してください';
    }
    
    // パスワードチェック
    if (!formData.password) {
      newErrors.password = 'パスワードは必須です';
    } else if (formData.password.length < 8) {
      newErrors.password = 'パスワードは8文字以上にしてください';
    } else if (formData.password.length > 72) {
      newErrors.password = 'パスワードは72文字以内で入力してください';
    }
    
    // パスワード確認
    if (formData.password !== formData.password_confirmation) {
      newErrors.password_confirmation = 'パスワードが一致しません';
    }
    
    // 利用規約同意
    if (!formData.terms_accepted) {
      newErrors.terms_accepted = '利用規約に同意する必要があります';
    }
    
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };
  
  const handleSubmit = async (e) => {
    e.preventDefault();
    setServerError('');
    
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
          role: formData.role
        }
      });
      
      if (result.ok) {
        // ユーザータイプに応じてリダイレクト
        const redirectPath = formData.role === 'organizer' ? '/dashboard' : '/events';
        router.push(redirectPath);
      } else {
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
      strong: 100
    }[strength];
    
    const label = {
      weak: '弱',
      medium: '中',
      strong: '強'
    }[strength];
    
    return (
      <div className={styles.passwordMeterContainer}>
        <div 
          className={`${styles.passwordMeter} ${styles[strength]}`}
          style={{ width: `${percent}%` }}
        />
        <div className={`${styles.passwordStrengthText} ${styles[`text${strength.charAt(0).toUpperCase() + strength.slice(1)}`]}`}>
          パスワード強度: {label}
        </div>
      </div>
    );
  };
  
  return (
    <div className={styles.authContainer || 'auth-container'}>
      <div className={styles.formContainer || 'form-container'}>
        <h1 className={styles.title || 'title'}>新規登録</h1>
        
        {serverError && <div className={styles.error || 'error'}>{serverError}</div>}
        
        <form onSubmit={handleSubmit} className={styles.form || 'form'}>
          <div className={styles.formGroup}>
            <label htmlFor="email">メールアドレス</label>
            <input
              id="email"
              name="email"
              type="email"
              value={formData.email}
              onChange={handleChange}
              className={`${styles.input} ${errors.email ? styles.inputError : ''}`}
            />
            {errors.email && <div className={styles.errorMessage}>{errors.email}</div>}
          </div>
          
          <div className={styles.formGroup}>
            <label htmlFor="name">氏名</label>
            <input
              id="name"
              name="name"
              type="text"
              value={formData.name}
              onChange={handleChange}
              className={`${styles.input} ${errors.name ? styles.inputError : ''}`}
            />
            {errors.name && <div className={styles.errorMessage}>{errors.name}</div>}
          </div>
          
          <div className={styles.formGroup}>
            <label htmlFor="password">パスワード</label>
            <input
              id="password"
              name="password"
              type="password"
              value={formData.password}
              onChange={handleChange}
              className={`${styles.input} ${errors.password ? styles.inputError : ''}`}
            />
            {formData.password && renderPasswordStrengthMeter()}
            {errors.password && <div className={styles.errorMessage}>{errors.password}</div>}
          </div>
          
          <div className={styles.formGroup}>
            <label htmlFor="password_confirmation">パスワード確認</label>
            <input
              id="password_confirmation"
              name="password_confirmation"
              type="password"
              value={formData.password_confirmation}
              onChange={handleChange}
              className={`${styles.input} ${errors.password_confirmation ? styles.inputError : ''}`}
            />
            {errors.password_confirmation && <div className={styles.errorMessage}>{errors.password_confirmation}</div>}
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
                /> イベント参加者
              </label>
              <label className={styles.radioLabel}>
                <input
                  type="radio"
                  name="role"
                  value="organizer"
                  checked={formData.role === 'organizer'}
                  onChange={handleChange}
                /> イベント主催者
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
              />
              <span>利用規約とプライバシーポリシーに同意します</span>
            </label>
            {errors.terms_accepted && <div className={styles.errorMessage}>{errors.terms_accepted}</div>}
          </div>
          
          <button
            type="submit"
            className={styles.submitButton || 'submit-button'}
            disabled={isLoading}
          >
            {isLoading ? '処理中...' : '登録する'}
          </button>
          
        </form>
        
        <div className={styles.loginLink || 'login-link'}>
          すでにアカウントをお持ちの方は <Link href="/login">ログイン</Link>
        </div>
      </div>
    </div>
  );
};

export default Register;
