FactoryBot.define do
  factory :ticket do
    name { "Standard Ticket" }
    price { 1000 }
    quantity { 100 }
    association :event
  end
end
