# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Create test user for development
if Rails.env.development?
  test_user = User.find_or_create_by(email_address: "john.doe@example.com") do |user|
    user.first_name = "John"
    user.last_name = "Doe"
    user.phone = "+1-555-123-4567"
    user.date_of_birth = Date.parse("1990-01-15")
    user.password = "Password123"
    user.password_confirmation = "Password123"
  end

  puts "Test user created/found: #{test_user.email_address}"
end
