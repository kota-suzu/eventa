FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password" }
    password_confirmation { "password" }
    name { "Test User" }

    factory :organizer do
      organizer { true }
    end
  end
end
