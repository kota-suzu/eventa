FactoryBot.define do
  factory :ticket_type do
    association :event
    sequence(:name) { |n| "チケットタイプ#{n}" }
    description { "チケットの説明文です" }
    price_cents { 100000 } # 1000円
    currency { "JPY" }
    quantity { 100 }
    sales_start_at { 1.day.ago }
    sales_end_at { 30.days.from_now }
    status { "draft" }

    trait :free do
      price_cents { 0 }
      name { "無料チケット" }
    end

    trait :on_sale do
      status { "on_sale" }
    end

    trait :soldout do
      status { "soldout" }
    end

    trait :closed do
      status { "closed" }
    end
  end
end 