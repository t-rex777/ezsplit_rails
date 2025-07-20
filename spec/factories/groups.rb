FactoryBot.define do
  factory :group do
    name { "Test Group" }
    description { "Fun group" }
    association :created_by, factory: :user
  end

  factory :group_membership do
    association :user
    association :group
    joined_at { Date.current }
  end
end
