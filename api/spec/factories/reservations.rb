FactoryBot.define do
  factory :reservation do
    quantity { 1 }
    status { "pending" }
    association :user
    association :ticket
  end
end
