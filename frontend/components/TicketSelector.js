import React, { useState } from 'react';
import PropTypes from 'prop-types';
import { formatCurrency } from '../utils/formatters';

const TicketSelector = ({ tickets, onSelect }) => {
  const [selectedQuantities, setSelectedQuantities] = useState(
    tickets.reduce((acc, ticket) => ({ ...acc, [ticket.id]: 0 }), {})
  );

  const handleQuantityChange = (ticketId, price, e) => {
    const quantity = parseInt(e.target.value, 10);

    setSelectedQuantities({
      ...selectedQuantities,
      [ticketId]: quantity,
    });

    // 親コンポーネントに選択情報を通知
    onSelect({
      ticketId,
      quantity,
      price,
      totalPrice: quantity * price,
    });
  };

  // <input type="number"> を <select> に置き換える
  const renderQuantitySelector = (ticket) => {
    const options = [];
    const maxQuantity = Math.min(ticket.available_quantity, 10); // 最大10枚まで

    for (let i = 0; i <= maxQuantity; i++) {
      options.push(
        <option key={i} value={i.toString()}>
          {i}枚
        </option>
      );
    }

    return (
      <select
        id={`quantity-${ticket.id}`}
        value={selectedQuantities[ticket.id].toString()}
        onChange={(e) => handleQuantityChange(ticket.id, ticket.price, e)}
        disabled={ticket.available_quantity <= 0}
        className="ticket-quantity-select"
      >
        {options}
      </select>
    );
  };

  return (
    <div className="ticket-selector">
      <h3>チケット選択</h3>
      <ul className="ticket-list">
        {tickets.map((ticket) => (
          <li key={ticket.id} className="ticket-item">
            <div className="ticket-info">
              <h4>{ticket.title}</h4>
              <p className="ticket-price">{formatCurrency(ticket.price)}</p>
              <p className="ticket-stock">
                {ticket.available_quantity > 0 ? (
                  `残り${ticket.available_quantity}枚`
                ) : (
                  <span className="sold-out">売り切れ</span>
                )}
              </p>
            </div>
            <div className="ticket-quantity">
              <label htmlFor={`quantity-${ticket.id}`}>数量</label>
              {renderQuantitySelector(ticket)}
            </div>
          </li>
        ))}
      </ul>
    </div>
  );
};

TicketSelector.propTypes = {
  tickets: PropTypes.arrayOf(
    PropTypes.shape({
      id: PropTypes.number.isRequired,
      title: PropTypes.string.isRequired,
      price: PropTypes.number.isRequired,
      available_quantity: PropTypes.number.isRequired,
    })
  ).isRequired,
  onSelect: PropTypes.func.isRequired,
};

export default TicketSelector;
