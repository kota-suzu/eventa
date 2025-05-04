FactoryBot.define do
  factory :event do
    sequence(:title) { |n| "イベント#{n}" }
    description { "イベントの説明文です" }
    start_at { 1.day.from_now }
    end_at { 2.days.from_now }
    venue { "テスト会場" }
    capacity { 100 }
    is_public { true }
    association :user

    trait :minimal do
      description { nil }
      to_create { |instance| instance.save(validate: false) }
    end
  end
end
