require 'rails_helper'

RSpec.describe SessionsController, type: :controller do
  describe "POST #create" do
    let(:user) { User.create!(email_address: "test@example.com", password: "password", password_confirmation: "password") }

    context "with valid credentials" do
      it "redirects to the root path" do
        post :create, params: { email_address: user.email_address, password: "password" }
        expect(response).to redirect_to(root_path)
      end

      it "sets a success notice" do
        post :create, params: { email_address: user.email_address, password: "password" }
        expect(flash[:notice]).to eq("Signed in successfully")
      end

      it "creates a new session" do
        expect {
          post :create, params: { email_address: user.email_address, password: "password" }
        }.to change(Session, :count).by(1)
      end
    end

    context "with invalid credentials" do
      it "redirects to the new session path" do
        post :create, params: { email_address: user.email_address, password: "wrong_password" }
        expect(response).to redirect_to(new_session_path)
      end

      it "sets an alert message" do
        post :create, params: { email_address: user.email_address, password: "wrong_password" }
        expect(flash[:alert]).to eq("Try another email address or password.")
      end

      it "does not create a new session" do
        expect {
          post :create, params: { email_address: user.email_address, password: "wrong_password" }
        }.to_not change(Session, :count)
      end
    end
  end
end
