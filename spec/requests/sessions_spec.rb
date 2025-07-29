require 'rails_helper'

RSpec.describe "Sessions", type: :request do
  let(:user) { create(:user) }

  describe "POST /session" do
    context "with valid credentials" do
      context "HTML format" do
        it "redirects to the root path" do
          post session_url, params: { email_address: user.email_address, password: "password" }
          expect(response).to redirect_to(root_path)
        end

        it "sets a success notice" do
          post session_url, params: { email_address: user.email_address, password: "password" }
          expect(flash[:notice]).to eq("Signed in successfully")
        end

        it "creates a new session" do
          expect {
            post session_url, params: { email_address: user.email_address, password: "password" }
          }.to change(Session, :count).by(1)
        end
      end

      context "JSON format" do
        it "returns successful JSON response" do
          post session_url, params: { email_address: user.email_address, password: "password" }, as: :json
          expect(response.content_type).to include('application/json')
          expect(response).to have_http_status(:ok)

          json_response = JSON.parse(response.body)
          expect(json_response['status']).to eq('success')
          expect(json_response['data']).to include('user', 'session')
          expect(json_response['data']['user']['data']['attributes']['email_address']).to eq(user.email_address)
        end

        it "creates a new session" do
          expect {
            post session_url, params: { email_address: user.email_address, password: "password" }, as: :json
          }.to change(Session, :count).by(1)
        end
      end
    end

    context "with invalid credentials" do
      context "HTML format" do
        it "redirects to the new session path" do
          post session_url, params: { email_address: user.email_address, password: "wrong_password" }
          expect(response).to redirect_to(new_session_path)
        end

        it "sets an alert message" do
          post session_url, params: { email_address: user.email_address, password: "wrong_password" }
          expect(flash[:alert]).to eq("Try another email address or password.")
        end

        it "does not create a new session" do
          expect {
            post session_url, params: { email_address: user.email_address, password: "wrong_password" }
          }.to_not change(Session, :count)
        end
      end

      context "JSON format" do
        it "returns error JSON response" do
          post session_url, params: { email_address: user.email_address, password: "wrong_password" }, as: :json
          expect(response.content_type).to include('application/json')
          expect(response).to have_http_status(:unauthorized)

          json_response = JSON.parse(response.body)
          expect(json_response['status']).to eq('error')
          expect(json_response['message']).to eq('Invalid email address or password')
          expect(json_response['errors']).to include('Invalid credentials')
        end

        it "does not create a new session" do
          expect {
            post session_url, params: { email_address: user.email_address, password: "wrong_password" }, as: :json
          }.to_not change(Session, :count)
        end
      end
    end
  end

  describe "GET /session" do
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
