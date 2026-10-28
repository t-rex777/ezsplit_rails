require "rails_helper"

RSpec.describe "Friend requests", type: :request do
  let!(:alice) { create(:user, first_name: "Alice", last_name: "A") }
  let!(:bob) { create(:user, first_name: "Bob", last_name: "B") }

  def json
    Oj.load(response.body)
  end

  describe "POST /invitations for an existing user" do
    before { sign_in(alice) }

    let(:params) { { invitation: { email_address: bob.email_address } } }

    it "creates a pending invitation and no friendship" do
      expect { post invitations_url, params: params }.to change(Invitation, :count).by(1)

      expect(Friendship.count).to eq(0)
      invitation = Invitation.last
      expect(invitation).to be_pending
      expect(invitation.inviter).to eq(alice)
      expect(invitation.invited_user).to eq(bob)
      expect(invitation.email).to eq(bob.email_address)
    end

    it "replies the same way as for a new user" do
      post invitations_url, params: params

      expect(response).to have_http_status(:created)
      expect(json).to eq("message" => "Invitation sent successfully.")
    end

    it "emails a friend request instead of an invite" do
      expect { post invitations_url, params: params }.to change { ActionMailer::Base.deliveries.count }.by(1)

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq([ bob.email_address ])
      expect(mail.body.encoded).to include("Alice A wants to add you as a friend on ezsplit")
    end

    it "does not create a second invitation while one is pending" do
      post invitations_url, params: params

      expect { post invitations_url, params: params }.not_to change(Invitation, :count)
      expect(response).to have_http_status(:created)
      expect(json).to eq("message" => "Invitation sent successfully.")
      expect(ActionMailer::Base.deliveries.count).to eq(1)
    end

    it "creates a new invitation when the earlier one expired" do
      create(:invitation, :expired, inviter: alice, email: bob.email_address, invited_user: bob)

      expect { post invitations_url, params: params }.to change(Invitation, :count).by(1)
    end

    it "keeps the already-a-friend reply" do
      create(:friendship, user: bob, friend: alice)

      expect { post invitations_url, params: params }.not_to change(Invitation, :count)
      expect(json["message"]).to eq("Bob B is already a friend.")
    end
  end

  describe "GET /invitations" do
    before { sign_in(bob) }

    it "lists pending, unexpired invitations sent to me, newest first" do
      older = create(:invitation, inviter: alice, email: bob.email_address, invited_user: bob, created_at: 2.days.ago)
      by_email = create(:invitation, inviter: create(:user, first_name: "Riya", last_name: "S"), email: bob.email_address.upcase)
      create(:invitation, :expired, inviter: alice, email: bob.email_address, invited_user: bob)
      create(:invitation, :accepted, inviter: alice, email: bob.email_address, invited_user: bob)
      create(:invitation, inviter: alice, email: "someone@else.com")

      get invitations_url, as: :json

      expect(response).to have_http_status(:ok)
      expect(json["data"].map { |row| row["id"] }).to eq([ by_email.id, older.id ])
      expect(json["data"].first).to eq(
        "id" => by_email.id,
        "created_at" => by_email.created_at.as_json,
        "inviter" => { "id" => by_email.inviter.id, "first_name" => "Riya", "last_name" => "S",
                       "email_address" => by_email.inviter.email_address }
      )
    end

    it "needs a signed-in user" do
      sign_out

      get invitations_url, as: :json

      expect(response).to have_http_status(:found)
    end
  end

  describe "POST /invitations/:id/accept" do
    let!(:invitation) { create(:invitation, inviter: alice, email: bob.email_address, invited_user: bob) }

    before { sign_in(bob) }

    it "makes both users friends and marks the invitation accepted" do
      post accept_invitation_url(invitation), as: :json

      expect(response).to have_http_status(:ok)
      expect(json).to eq("message" => "You are now friends with Alice A.")
      expect(alice.friends).to eq([ bob ])
      expect(bob.friends).to eq([ alice ])
      invitation.reload
      expect(invitation).to be_accepted
      expect(invitation.status).to eq("accepted")
      expect(invitation.invited_user).to eq(bob)
    end

    it "works for an invitation matched only by email" do
      by_email = create(:invitation, inviter: create(:user), email: bob.email_address)

      post accept_invitation_url(by_email), as: :json

      expect(response).to have_http_status(:ok)
      expect(by_email.reload.invited_user).to eq(bob)
    end

    it "does not duplicate an existing friendship" do
      create(:friendship, user: alice, friend: bob)

      expect { post accept_invitation_url(invitation), as: :json }.to change(Friendship, :count).by(1)
      expect(response).to have_http_status(:ok)
    end

    it "returns 404 for an invitation sent to someone else" do
      sign_out
      sign_in(create(:user))

      post accept_invitation_url(invitation), as: :json

      expect(response).to have_http_status(:not_found)
      expect(json).to eq("errors" => [ "Invitation not found." ])
      expect(Friendship.count).to eq(0)
    end

    it "returns 404 for an unknown invitation" do
      post accept_invitation_url(0), as: :json

      expect(response).to have_http_status(:not_found)
      expect(json).to eq("errors" => [ "Invitation not found." ])
    end

    it "returns 422 for an expired invitation" do
      invitation.update!(expires_at: 1.day.ago)

      post accept_invitation_url(invitation), as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json).to eq("errors" => [ "This invitation is no longer valid." ])
      expect(Friendship.count).to eq(0)
    end

    it "returns 422 for an invitation that is not pending" do
      invitation.update!(status: :rejected)

      post accept_invitation_url(invitation), as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Friendship.count).to eq(0)
    end
  end

  describe "POST /invitations/:id/decline" do
    let!(:invitation) { create(:invitation, inviter: alice, email: bob.email_address, invited_user: bob) }

    before { sign_in(bob) }

    it "rejects the invitation and creates no friendship" do
      post decline_invitation_url(invitation), as: :json

      expect(response).to have_http_status(:ok)
      expect(json).to eq("message" => "Invitation declined.")
      expect(invitation.reload.status).to eq("rejected")
      expect(Friendship.count).to eq(0)
    end

    it "returns 404 for an invitation sent to someone else" do
      sign_out
      sign_in(alice)

      post decline_invitation_url(invitation), as: :json

      expect(response).to have_http_status(:not_found)
      expect(json).to eq("errors" => [ "Invitation not found." ])
      expect(invitation.reload).to be_pending
    end

    it "returns 422 once the invitation is no longer pending" do
      invitation.update!(status: :accepted, accepted_at: Time.current)

      post decline_invitation_url(invitation), as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json).to eq("errors" => [ "This invitation is no longer valid." ])
    end
  end
end
