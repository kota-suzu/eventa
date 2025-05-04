# frozen_string_literal: true

FactoryBot.define do
  factory :reservation do
    quantity { 2 }
    total_price { 2000 }
    status { "pending" }
    payment_method { "credit_card" }
    association :user
    association :ticket

    trait :confirmed do
      status { "confirmed" }
    end

    trait :payment_failed do
      status { "payment_failed" }
    end
  end
end
