# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invitation, type: :model do
  context "associations" do
    it { should belong_to(:invited_user).optional }
    it { should belong_to(:inviter).class_name('User') }
  end

  context "validations" do
    it { should validate_presence_of(:status) }
    it { should define_enum_for(:status).with_values(pending: 0, accepted: 1, rejected: 2, expired: 3) }
    it { should validate_presence_of(:email) }
    it { should allow_value('user@example.com').for(:email) }
    it { should validate_presence_of(:inviter) }
  end

  context "token generation" do
    it "generates a secure token on creation" do
      invitation = create(:invitation)
      expect(invitation.token).to be_present
      expect(invitation.token).to be_a(String)
    end

    it "generates unique tokens for different invitations" do
      invitation1 = create(:invitation)
      invitation2 = create(:invitation)
      expect(invitation1.token).not_to eq(invitation2.token)
    end
  end

  context "callbacks" do
    describe "#set_expiration" do
      it "sets expires_at to 7 days from now on creation" do
        Timecop.freeze do
          invitation = create(:invitation)
          expect(invitation.expires_at).to eq(Time.now + 7.days)
        end

        Timecop.return
      end

      it "does not modify expires_at on update" do
        invitation = create(:invitation)
        original_expires_at = invitation.expires_at

        invitation.update!(status: :accepted)
        expect(invitation.expires_at).to eq(original_expires_at)
      end
    end
  end

  context "instance methods" do
    describe "#expired?" do
      it "returns true when invitation has expired" do
        invitation = create(:invitation, expires_at: 1.day.ago)
        expect(invitation.expired?).to be true
      end

      it "returns false when invitation has not expired" do
        invitation = create(:invitation, expires_at: 1.day.from_now)
        expect(invitation.expired?).to be false
      end
    end

    describe "#accepted?" do
      it "returns true when accepted_at is present" do
        invitation = create(:invitation, accepted_at: Time.now)
        expect(invitation.accepted?).to be true
      end

      it "returns false when accepted_at is nil" do
        invitation = create(:invitation, accepted_at: nil)
        expect(invitation.accepted?).to be false
      end
    end
  end

  context "scopes and queries" do
    it "can query by status" do
      pending_invitation = create(:invitation, :pending)
      accepted_invitation = create(:invitation, :accepted)
      rejected_invitation = create(:invitation, :rejected)

      expect(Invitation.pending).to include(pending_invitation)
      expect(Invitation.accepted).to include(accepted_invitation)
      expect(Invitation.rejected).to include(rejected_invitation)
    end
  end

  context "edge cases" do
    it "validates email format with various valid emails" do
      valid_emails = [
        "test@example.com",
        "user+tag@domain.co.uk",
        "name.lastname@subdomain.domain.org"
      ]

      valid_emails.each do |email|
        invitation = build(:invitation, email: email)
        expect(invitation).to be_valid, "Expected #{email} to be valid"
      end
    end

    it "rejects invalid email formats" do
      invalid_emails = [
        "invalid-email",
        "@domain.com",
        "user@",
        "user space@domain.com"
      ]

      invalid_emails.each do |email|
        invitation = build(:invitation, email: email)
        expect(invitation).not_to be_valid, "Expected #{email} to be invalid"
        expect(invitation.errors[:email]).to be_present
      end
    end
  end

  context "token security" do
    it "regenerates token when explicitly called" do
      invitation = create(:invitation)
      original_token = invitation.token

      invitation.regenerate_token
      expect(invitation.token).not_to eq(original_token)
      expect(invitation.token).to be_present
    end

    it "maintains token through updates that don't affect it" do
      invitation = create(:invitation)
      original_token = invitation.token

      invitation.update!(status: :accepted)
      expect(invitation.token).to eq(original_token)
    end
  end
end
