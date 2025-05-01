import { useState } from 'react';
import { useRouter } from 'next/router';
import Head from 'next/head';
import Link from 'next/link';
import styles from '../styles/Auth.module.css';
import Header from '../components/Header';
import { useAuth } from '../contexts/AuthContext';
import { post } from '../utils/api';

export default function Login() {
  const router = useRouter();
  const { login } = useAuth();
  const [formData, setFormData] = useState({
    email: '',
    password: ''
  });
  const [errors, setErrors] = useState({});
  const [isLoading, setIsLoading] = useState(false);
  const [apiError, setApiError] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault();
    
    if (!validateForm()) {
      return;
    }

    setIsLoading(true);
    setApiError('');

    try {
      const data = await post('/api/v1/auth/login', formData);
      
      // 認証コンテキストを使ってログイン
      login(data.meta.token, data.data);
      
      // リダイレクト先がある場合はそちらに、なければホームページへ
      const redirectPath = router.query.redirect || '/';
      router.push(redirectPath);
    } catch (error) {
      console.error('Login error:', error);
      setApiError(error.message || 'メールアドレスまたはパスワードが正しくありません。');
    } finally {
      setIsLoading(false);
    }
  };
}