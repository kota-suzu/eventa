FactoryBot.define do
  factory :event do
    title { "テストイベント" }
    description { "これはテスト用のイベントです" }
    start_at { 1.day.from_now }
    end_at { 2.days.from_now }
    venue { "テスト会場" }
    capacity { 100 }
    association :user, factory: :organizer

    trait :with_tickets do
      after(:create) do |event|
        create(:ticket, event: event)
      end
    end
  end
end 