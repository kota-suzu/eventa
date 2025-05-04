FactoryBot.define do
  factory :reservation do
    association :user
    association :ticket
    quantity { 1 }
    total_price { 1000 }
    status { 0 } # pending
    payment_method { 0 } # credit_card

    trait :completed do
      status { 1 } # confirmed
    end

    trait :cancelled do
      status { 3 } # cancelled
    end
  end
end 