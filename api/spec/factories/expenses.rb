FactoryBot.define do
  factory :expense do
    name { "Test Expense" }
    amount { 100.0 }
    split_type { :equal }
    currency { "INR" }
    expense_date { Date.current }

    association :payer, factory: :user
    association :group
    association :category
    association :user, factory: :user
  end
end
