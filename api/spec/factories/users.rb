FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    name { "Test User" }
    role { :guest }
    status { :active }

    factory :organizer do
      role { :organizer }
    end

    factory :admin do
      role { :admin }
    end
  end
end
