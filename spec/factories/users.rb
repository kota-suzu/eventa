FactoryBot.define do
  factory :user do
    name { "テストユーザー" }
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    role { :guest }
    session_id { nil }
  end

  # 主催者ロールのユーザー
  factory :organizer, class: 'User' do
    name { "主催者ユーザー" }
    sequence(:email) { |n| "organizer#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    role { :organizer }
    session_id { nil }
  end

  # 管理者ロールのユーザー
  factory :admin, class: 'User' do
    name { "管理者ユーザー" }
    sequence(:email) { |n| "admin#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    role { :admin }
    session_id { nil }
  end
end 