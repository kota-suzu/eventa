def set_from_ticket_type
  set_ticket_title
  set_ticket_description
  set_ticket_price
end

# タイトルを設定
def set_ticket_title
  self.title = ticket_type.name if title.blank?
end

# 説明を設定
def set_ticket_description
  self.description = ticket_type.description if description.blank?
end

# 価格を設定
def set_ticket_price
  self.price = ticket_type.price_cents / 100 if price.blank?
end
