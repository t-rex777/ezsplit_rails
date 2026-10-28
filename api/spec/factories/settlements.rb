FactoryBot.define do
  factory :settlement do
    association :payer, factory: :user
    association :payee, factory: :user
    amount { 10 }
    currency { "INR" }
    settled_on { Date.current }
  end
end
