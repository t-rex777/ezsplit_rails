FactoryBot.define do
  factory :group do
    name { "Test Group" }
    description { "Fun group" }
    association :created_by, factory: :user
  end
end 