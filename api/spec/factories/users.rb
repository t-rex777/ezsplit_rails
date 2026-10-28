FactoryBot.define do
  factory :user do
    sequence(:email_address) { |n| "test#{n}@example.com" }
    password { "password" }
    password_confirmation { "password" }
    first_name { "Test" }
    last_name { "User" }
    phone { "1234567890" }
    date_of_birth { "2000-01-01" }
  end
end
