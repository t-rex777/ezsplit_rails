FactoryBot.define do
  factory :invitation do
    sequence(:email) { |n| "invited#{n}@example.com" }
    status { :pending }
    association :inviter, factory: :user
    invited_user { nil }
    expires_at { 7.days.from_now }

    trait :pending do
      status { :pending }
    end

    trait :accepted do
      status { :accepted }
      accepted_at { Time.current }
    end

    trait :rejected do
      status { :rejected }
    end

    trait :expired do
      expires_at { 1.day.ago }
    end

    trait :with_invited_user do
      association :invited_user, factory: :user
    end
  end
end
