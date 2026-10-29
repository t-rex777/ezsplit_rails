require 'rails_helper'

RSpec.describe "UserRegisters", type: :request do
  describe "POST /user_register" do
    let!(:invite) { create(:invitation, email: "test@test.com") }

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
        },
        token: invite.token
      }
      post user_registers_url, params: user_params
      expect(response).to have_http_status(:ok)
    end

    it "gives the new user the five default categories" do
      user_params = {
        user: {
          email_address: "test@test.com",
          password: "helloWorld",
          password_confirmation: "helloWorld",
          first_name: "Test",
          last_name: "Test",
          phone: "9876543210",
          date_of_birth: "2000-05-01"
        },
        token: invite.token
      }
      post user_registers_url, params: user_params

      user = User.find_by!(email_address: "test@test.com")
      expect(user.categories.order(:id).pluck(:name)).to eq([ "Grocery", "Travel", "Entertainment", "Dining", "Personal Care" ])
    end

    it "sends a welcome email when user is created successfully" do
      user_params = {
        user: {
          email_address: "test@test.com",
          password: "helloWorld",
          password_confirmation: "helloWorld",
          first_name: "Test",
          last_name: "Test",
          phone: "9876543210",
          date_of_birth: "2000-05-01"
        },
        token: invite.token
      }

      expect {
        post user_registers_url, params: user_params
      }.to change { ActionMailer::Base.deliveries.count }.by(1)

      expect(response).to have_http_status(:ok)

      # Verify the email was sent to the correct user
      last_email = ActionMailer::Base.deliveries.last
      expect(last_email.to).to include("test@test.com")
      expect(last_email.subject).to eq("Welcome to EZSplit!")
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

    context "when token is provided" do
      let(:inviter) { create(:user) }
      let(:invitation) { create(:invitation, inviter: inviter, email: "newuser@test.com") }

      it "accepts the invitation during user registration" do
        user_params = {
          user: {
            email_address: "newuser@test.com",
            password: "helloWorld",
            password_confirmation: "helloWorld",
            first_name: "New",
            last_name: "User",
            phone: "9876543210",
            date_of_birth: "2000-05-01"
          },
          token: invitation.token
        }

        expect {
          post user_registers_url, params: user_params
        }.to change { User.count }.by(1)
          .and change { Friendship.count }.by(2)

        expect(response).to have_http_status(:ok)

        # Verify the invitation was accepted
        invitation.reload
        expect(invitation.status).to eq('accepted')
        expect(invitation.accepted_at).to be_present

        # Verify friendships were created
        new_user = User.find_by(email_address: "newuser@test.com")
        expect(new_user.friends).to include(inviter)
        expect(inviter.friends).to include(new_user)
      end

      it "refuses sign-up when the token is invalid" do
        user_params = {
          user: {
            email_address: "newuser@test.com",
            password: "helloWorld",
            password_confirmation: "helloWorld",
            first_name: "New",
            last_name: "User",
            phone: "9876543210",
            date_of_birth: "2000-05-01"
          },
          token: "invalid_token"
        }

        expect {
          post user_registers_url, params: user_params
        }.not_to change { User.count }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
