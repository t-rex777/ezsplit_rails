require 'rails_helper'

RSpec.describe "Invitations", type: :request do
  let!(:user) { create(:user) }
  let!(:invited_user) { create(:user) }
  let!(:invitation) { create(:invitation, inviter: user) }

  describe "POST /invitations" do
    context "when user is authenticated" do
      before { sign_in(user) }

      context "with valid parameters" do
        let(:valid_params) do
          {
            invitation: {
              email_address: "friend@example.com",
              message: "Join me on the app!"
            }
          }
        end

        it "creates a new invitation" do
          expect {
            post invitations_path, params: valid_params
          }.to change(Invitation, :count).by(1)
        end

        it "sends an invitation email" do
          expect {
            post invitations_path, params: valid_params
          }.to change { ActionMailer::Base.deliveries.count }.by(1)

          last_email = ActionMailer::Base.deliveries.last
          expect(last_email.to).to include("friend@example.com")
          expect(last_email.subject).to eq("You're invited to join EZSplit!")
        end

        it "returns success response" do
          post invitations_path, params: valid_params

          expect(response).to have_http_status(:created)
          expect(JSON.parse(response.body)["message"]).to eq("Invitation sent successfully.")
        end

        it "sets the inviter to current user" do
          post invitations_path, params: valid_params

          created_invitation = Invitation.last
          expect(created_invitation.inviter).to eq(user)
        end

        it "sets invitation status to pending" do
          post invitations_path, params: valid_params

          created_invitation = Invitation.last
          expect(created_invitation.status).to eq("pending")
        end

        it "generates a secure token" do
          post invitations_path, params: valid_params

          created_invitation = Invitation.last
          expect(created_invitation.token).to be_present
        end
      end

      context "with invalid parameters" do
        let(:invalid_params) do
          {
            invitation: {
              email: "invalid-email",
              message: "Join me!"
            }
          }
        end

        it "does not create a new invitation" do
          expect {
            post invitations_path, params: invalid_params
          }.not_to change(Invitation, :count)
        end

        it "returns unprocessable entity status" do
          post invitations_path, params: invalid_params

          expect(response).to have_http_status(:unprocessable_entity)
        end

        it "returns validation errors" do
          post invitations_path, params: invalid_params

          response_body = JSON.parse(response.body)
          expect(response_body["errors"]).to be_present
          expect(response_body["errors"]).to include(match(/Email is invalid/))
        end
      end

      context "with missing email" do
        let(:params_without_email) do
          {
            invitation: {
              message: "Join me!"
            }
          }
        end

        it "returns validation errors" do
          post invitations_path, params: params_without_email

          expect(response).to have_http_status(:unprocessable_entity)
          response_body = JSON.parse(response.body)
          expect(response_body["errors"]).to include(match(/Email can't be blank/))
        end
      end

      context "with missing invitation params" do
        it "raises parameter missing error" do
          post invitations_path, params: { other_param: "value" }

          expect(response).to have_http_status(:bad_request)
        end
      end
    end

    context "when user is not authenticated" do
      it "requires authentication" do
        post invitations_path, params: {
          invitation: {
            email: "friend@example.com",
            message: "Join me!"
          }
        }

        expect(response).to have_http_status(:found)
        expect(response).to redirect_to(new_session_path)
      end
    end
  end

  describe "PUT /invitations/:id" do
    context "with new user" do
      it "returns user not found" do
        put "/invitations/#{invitation.id}", params: {
          invitation: {
            token: invitation.token,
            email_address: "hulk@test.com"
          }
        }

        response_body = Oj.load(response.body)
        expect(response).to have_http_status(:not_found)
        expect(response_body["message"]).to eq("User not found. Please create a new account.")
      end
    end

    context "with existing user" do
      it "updates invitation and creates friendship" do
        put "/invitations/#{invitation.id}", params: {
          invitation: {
            token: invitation.token,
            email_address: invited_user.email_address
          }
        }

        invitation.reload
        response_body = Oj.load(response.body)

        expect(response).to have_http_status(:ok)
        expect(invitation.invited_user).to eq(invited_user)
        expect(invited_user.friendships.count).to eq(1)
        expect(invited_user.friendships.first.friend).to eq(invitation.inviter)
      end

      it "returns error when invitation is not found" do
        put "/invitations/999", params: {
          invitation: {
            token: invitation.token,
            email_address: invited_user.email_address
          }
        }

        response_body = Oj.load(response.body)
        expect(response).to have_http_status(:not_found)
        expect(response_body["message"]).to eq("Invitation not found.")
      end

      it "returns error when invitation is expired" do
        invitation.update!(status: :expired, expires_at: 1.day.ago)

        put "/invitations/#{invitation.id}", params: {
          invitation: {
            token: invitation.token,
            email_address: invited_user.email_address
          }
        }

        response_body = Oj.load(response.body)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response_body["message"]).to eq("Invitation has expired.")
      end

      it "returns error when invitation is already accepted" do
        invitation.update!(status: :accepted, accepted_at: 1.day.ago)

        put "/invitations/#{invitation.id}", params: {
          invitation: {
            token: invitation.token,
            email_address: invited_user.email_address
          }
        }

        response_body = Oj.load(response.body)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response_body["message"]).to eq("Invitation has already been accepted.")
      end

      it "returns error when invitation is invalid token" do
        put "/invitations/#{invitation.id}", params: {
          invitation: {
            token: "random_token",
            email_address: invited_user.email_address
          }
        }

        response_body = Oj.load(response.body)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response_body["message"]).to eq("Invalid invitation token.")
      end
    end
  end
end
