FactoryBot.define do
  factory :ticket do
    title { "一般チケット" }
    description { "一般参加者向けのチケットです" }
    price { 1000 }
    quantity { 50 }
    available_quantity { 50 }
    association :event
  end

  factory :free_ticket, class: 'Ticket' do
    title { "無料チケット" }
    description { "無料で参加できるチケットです" }
    price { 0 }
    quantity { 30 }
    available_quantity { 30 }
    association :event
  end

  factory :premium_ticket, class: 'Ticket' do
    title { "プレミアムチケット" }
    description { "特典付きの参加チケットです" }
    price { 5000 }
    quantity { 10 }
    available_quantity { 10 }
    association :event
  end
end 