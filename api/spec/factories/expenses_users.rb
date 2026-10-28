FactoryBot.define do
  factory :expenses_user do
    association :expense
    association :user
    amount { 9.99 }
  end
end
