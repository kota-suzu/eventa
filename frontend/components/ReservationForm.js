import React, { useState, useContext, useRef, useEffect } from 'react';
import { useRouter } from 'next/router';
import PropTypes from 'prop-types';
import { AuthContext } from '../contexts/AuthContext';
import TicketSelector from './TicketSelector';
import { createReservation } from '../utils/api';
import { formatCurrency } from '../utils/formatters';

const ReservationForm = ({ eventId, tickets }) => {
  const router = useRouter();
  const { user, isAuthenticated } = useContext(AuthContext);
  const [selectedTicket, setSelectedTicket] = useState(null);
  const [paymentMethod, setPaymentMethod] = useState('credit_card');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState('');
  const isMounted = useRef(true);

  // アンマウント検出用
  useEffect(() => {
    return () => {
      isMounted.current = false;
    };
  }, []);

  const handleTicketSelect = (ticketData) => {
    setSelectedTicket(ticketData);
  };

  const handlePaymentMethodChange = (e) => {
    setPaymentMethod(e.target.value);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');

    if (!selectedTicket || selectedTicket.quantity <= 0) {
      setError('チケットを選択してください');
      return;
    }

    if (!isAuthenticated) {
      setError('予約にはログインが必要です');
      return;
    }

    setIsSubmitting(true);

    try {
      const response = await createReservation({
        ticket_id: selectedTicket.ticketId,
        quantity: selectedTicket.quantity,
        payment_method: paymentMethod,
      });

      // Next.jsのルーターで遷移
      router.push(response.payment_url);
    } catch (err) {
      // アンマウントされていない場合のみ状態更新
      if (isMounted.current) {
        setError(err.response?.data?.error || 'エラーが発生しました');
        setIsSubmitting(false);
      }
    }
  };

  return (
    <div className="reservation-form">
      <h2>チケット予約</h2>

      {error && <div className="error-message">{error}</div>}

      <form onSubmit={handleSubmit}>
        <TicketSelector tickets={tickets} onSelect={handleTicketSelect} />

        {selectedTicket && selectedTicket.quantity > 0 && (
          <>
            <div className="payment-section">
              <h3>支払い方法</h3>
              <div className="payment-methods">
                <div className="payment-method">
                  <input
                    type="radio"
                    id="credit_card"
                    name="payment_method"
                    value="credit_card"
                    checked={paymentMethod === 'credit_card'}
                    onChange={handlePaymentMethodChange}
                  />
                  <label htmlFor="credit_card">クレジットカード</label>
                </div>

                <div className="payment-method">
                  <input
                    type="radio"
                    id="bank_transfer"
                    name="payment_method"
                    value="bank_transfer"
                    checked={paymentMethod === 'bank_transfer'}
                    onChange={handlePaymentMethodChange}
                  />
                  <label htmlFor="bank_transfer">銀行振込</label>
                </div>

                <div className="payment-method">
                  <input
                    type="radio"
                    id="convenience_store"
                    name="payment_method"
                    value="convenience_store"
                    checked={paymentMethod === 'convenience_store'}
                    onChange={handlePaymentMethodChange}
                  />
                  <label htmlFor="convenience_store">コンビニ決済</label>
                </div>
              </div>
            </div>

            <div className="user-info">
              <h3>予約者情報</h3>
              <div className="form-group">
                <label htmlFor="name">名前</label>
                <input type="text" id="name" value={user?.name || ''} readOnly />
              </div>

              <div className="form-group">
                <label htmlFor="email">メールアドレス</label>
                <input type="email" id="email" value={user?.email || ''} readOnly />
              </div>
            </div>

            <div className="reservation-summary">
              <h3>予約内容</h3>
              <p>選択チケット: {tickets.find((t) => t.id === selectedTicket.ticketId)?.title}</p>
              <p>数量: {selectedTicket.quantity}枚</p>
              <p>合計金額: {formatCurrency(selectedTicket.totalPrice)}</p>
            </div>

            <div className="form-actions">
              <button type="submit" disabled={isSubmitting || !isAuthenticated}>
                {isSubmitting ? '処理中...' : '予約する'}
              </button>
            </div>
          </>
        )}
      </form>
    </div>
  );
};

ReservationForm.propTypes = {
  eventId: PropTypes.number.isRequired,
  tickets: PropTypes.arrayOf(
    PropTypes.shape({
      id: PropTypes.number.isRequired,
      title: PropTypes.string.isRequired,
      price: PropTypes.number.isRequired,
      available_quantity: PropTypes.number.isRequired,
    })
  ).isRequired,
};

export default ReservationForm;
