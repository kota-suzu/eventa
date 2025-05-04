# frozen_string_literal: true

FactoryBot.define do
  factory :event do
    title { "テストイベント" }
    description { "テストイベントの説明です" }
    start_at { 2.days.from_now }
    end_at { 3.days.from_now }
    venue { "テスト会場" }
    capacity { 100 }
    association :user
  end
end
