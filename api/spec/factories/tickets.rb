# frozen_string_literal: true

FactoryBot.define do
  factory :ticket do
    title { "一般チケット" }
    description { "イベントの一般入場チケットです" }
    price { 1000 }
    quantity { 10 }
    available_quantity { 10 }
    association :event

    trait :vip do
      title { "VIPチケット" }
      price { 3000 }
      quantity { 5 }
      available_quantity { 5 }
    end

    trait :sold_out do
      quantity { 0 }
    end
  end
end
