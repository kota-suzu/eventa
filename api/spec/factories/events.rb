FactoryBot.define do
  factory :event do
    sequence(:name) { |n| "Event #{n}" }
    sequence(:description) { |n| "Description for event #{n}" }
    start_at { 1.day.from_now }
    end_at { 2.days.from_now }
    venue { "Test Venue" }
    address { "123 Test Street" }
    association :organizer, factory: :organizer
  end
end
