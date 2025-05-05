FactoryBot.define do
  factory :reservation do
    quantity { 1 }
    status { "pending" }
    payment_method { "credit_card" }  # デフォルトの支払い方法を設定
    association :user
    association :ticket
  end
end
