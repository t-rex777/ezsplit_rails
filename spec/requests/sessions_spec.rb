require 'rails_helper'

RSpec.describe "Sessions", type: :request do
  let!(:user) { create(:user) }

  describe "POST /sessions" do
    it "creates a session with correct credentials" do
      post session_url, params: { email_address: user.email_address, password: user.password }
      expect(response).to have_http_status(302)
    end
  end

  describe "GET /sessions" do
    before do
      post session_url, params: { email_address: user.email_address, password: user.password }
    end

    it "returns current user's session" do
      get session_url
      response_body = Oj.load(response.body)
      expect(response).to be_successful
    end
  end
end
