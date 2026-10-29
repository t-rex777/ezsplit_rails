require "rails_helper"

RSpec.describe "QR invitations", type: :request do
  let!(:inviter) { create(:user) }

  def sign_up(token, email)
    post user_registers_url, params: {
      token: token,
      user: {
        email_address: email,
        password: "helloWorld",
        password_confirmation: "helloWorld",
        first_name: "New",
        last_name: "Person",
        phone: "9876543210",
        date_of_birth: "2000-05-01"
      }
    }
  end

  describe "POST /invitations/qr" do
    it "creates a one-use invite with no email and returns the link to encode" do
      sign_in(inviter)

      sent_before = ActionMailer::Base.deliveries.count
      expect { post qr_invitations_path }.to change(Invitation, :count).by(1)
      expect(ActionMailer::Base.deliveries.count).to eq(sent_before)

      expect(response).to have_http_status(:created)
      invitation = Invitation.last
      expect(invitation).to be_kind_qr
      expect(invitation.email).to be_nil
      expect(invitation.inviter).to eq(inviter)
      body = JSON.parse(response.body)
      expect(body["url"]).to eq("http://example.com/register?token=#{invitation.token}")
      expect(Time.zone.parse(body["expires_at"])).to be_within(1.minute).of(7.days.from_now)
    end

    it "requires a signed-in user" do
      expect { post qr_invitations_path }.not_to change(Invitation, :count)
      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "signing up with a QR invite" do
    let!(:invitation) { create(:invitation, :qr, inviter: inviter) }

    it "takes any email, creates the user, and makes them friends" do
      expect { sign_up(invitation.token, "scanner@example.com") }
        .to change(User, :count).by(1).and change(Friendship, :count).by(2)

      expect(response).to have_http_status(:ok)
      new_user = User.find_by(email_address: "scanner@example.com")
      expect(new_user.friends).to include(inviter)
      expect(inviter.friends).to include(new_user)
      expect(invitation.reload).to be_accepted
      expect(invitation.invited_user).to eq(new_user)
    end

    it "works only once" do
      sign_up(invitation.token, "first@example.com")
      sign_out

      expect { sign_up(invitation.token, "second@example.com") }.not_to change(User, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["errors"]).to eq([ "This invite has already been used. Ask your friend for a new one." ])
    end

    it "fails once expired" do
      invitation.update!(expires_at: 1.minute.ago)

      expect { sign_up(invitation.token, "late@example.com") }.not_to change(User, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["errors"]).to eq([ "This invite has expired. Ask your friend for a new one." ])
    end

    it "cannot friend an existing user through the email-accept endpoint" do
      existing = create(:user)

      put invitation_path(invitation), params: { invitation: { token: invitation.token, email_address: existing.email_address } }

      expect(response).to have_http_status(:not_found)
      expect(existing.friends).not_to include(inviter)
      expect(invitation.reload).to be_pending
    end

    it "does not show up as a friend request" do
      sign_in(create(:user))
      get invitations_path
      expect(JSON.parse(response.body)["data"]).to be_empty
    end
  end

  describe "email invites" do
    it "still need the invited email to sign up" do
      invitation = create(:invitation, inviter: inviter, email: "invited@example.com")

      expect { sign_up(invitation.token, "someone-else@example.com") }.not_to change(User, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["errors"]).to eq([ UserRegistersController::INVITE_REQUIRED ])
    end
  end

  describe "GET /register with a QR link" do
    it "hands the app a link with no email" do
      get "/register", params: { token: "abc" }

      expect(response.body).to include("ezsplit://register?token=abc\"")
    end
  end
end
