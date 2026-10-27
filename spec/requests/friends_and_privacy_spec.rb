require "rails_helper"

RSpec.describe "Friends and privacy", type: :request do
  let!(:alice) { create(:user, first_name: "Alice") }
  let!(:bob) { create(:user, first_name: "Bob") }
  let!(:carol) { create(:user, first_name: "Carol") }

  describe "GET /users" do
    it "lists my friends without phone numbers or dates of birth" do
      create(:friendship, user: alice, friend: bob)
      sign_in(alice)

      get users_url
      data = Oj.load(response.body)["data"]
      expect(data.map { |u| u["id"] }).to eq([ bob.id.to_s ])
      expect(data.first["attributes"].keys).not_to include("phone", "date_of_birth")

      get users_search_url, params: { term: "Bob" }
      expect(Oj.load(response.body)["data"].first["attributes"].keys).not_to include("phone", "date_of_birth")
    end
  end

  describe "POST /session" do
    it "does not write the password to the log" do
      log = StringIO.new
      original_logger = Rails.logger
      Rails.logger = ActiveSupport::Logger.new(log)

      post session_url, params: { email_address: alice.email_address, password: "password" }

      Rails.logger = original_logger
      expect(log.string).not_to include("\"password\"=>\"password\"")
    end
  end

  describe "POST /user_registers with an invitation token" do
    let(:user_params) do
      { email_address: "dave@example.com", password: "secret12", password_confirmation: "secret12",
        first_name: "Dave", last_name: "D", phone: "1", date_of_birth: "1990-01-01" }
    end

    it "signs up and becomes friends with the inviter" do
      invitation = create(:invitation, inviter: alice, email: "dave@example.com")

      post user_registers_url, params: { token: invitation.token, user: user_params }

      expect(response).to have_http_status(:ok)
      dave = User.find_by(email_address: "dave@example.com")
      expect(dave.friends).to eq([ alice ])
      expect(alice.friends).to eq([ dave ])
      expect(invitation.reload).to be_accepted
    end

    it "still signs up when the invitation was for someone else" do
      invitation = create(:invitation, inviter: alice, email: "someone@example.com")

      post user_registers_url, params: { token: invitation.token, user: user_params }

      expect(response).to have_http_status(:ok)
      expect(User.find_by(email_address: "dave@example.com").friends).to be_empty
    end
  end
end
