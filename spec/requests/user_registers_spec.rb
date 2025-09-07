require 'rails_helper'

RSpec.describe "UserRegisters", type: :request do
  describe "POST /user_register" do
    it "creates a new user with valid params" do
      user_params = {
        user: {
          email_address: "test@test.com",
          password: "helloWorld",
          password_confirmation: "helloWorld",
          first_name: "Test",
          last_name: "Test",
          phone: "9876543210",
          date_of_birth: "2000-05-01"
        }
      }
      post user_registers_url, params: user_params
      expect(response).to have_http_status(:ok)
    end

    it "does not creates a new user with invalid params" do
      user_params = {
        user: {
          email_address: "test",
          password: "helloWorld",
          password_confirmation: "helloWorld",
          first_name: "Test",
          last_name: "Test",
          phone: "9876543210",
          date_of_birth: "2000-05-01"
        }
      }
      post user_registers_url, params: user_params
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
