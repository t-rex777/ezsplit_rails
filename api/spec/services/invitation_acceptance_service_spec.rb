require 'rails_helper'

RSpec.describe InvitationAcceptanceService, type: :service do
  let(:inviter) { create(:user) }
  let(:invited_user) { create(:user) }
  let(:invitation) { create(:invitation, inviter: inviter, email: invited_user.email_address) }
  let(:token) { invitation.token }

  describe '#call' do
    context 'when invitation is valid' do
      it 'accepts the invitation and creates friendships' do
        service = described_class.new(invitation, invited_user, token)
        result = service.call

        expect(result[:success]).to be true
        expect(result[:message]).to eq("User invited successfully.")

        invitation.reload
        expect(invitation.status).to eq('accepted')
        expect(invitation.accepted_at).to be_present
        expect(invitation.invited_user).to eq(invited_user)

        expect(invited_user.friends).to include(inviter)
        expect(inviter.friends).to include(invited_user)
      end
    end

    context 'when invitation is expired' do
      before do
        invitation.update!(expires_at: 1.day.ago)
      end

      it 'returns an error' do
        service = described_class.new(invitation, invited_user, token)
        result = service.call

        expect(result[:success]).to be false
        expect(result[:error]).to eq("Invitation has expired.")
      end
    end

    context 'when invitation is already accepted' do
      before do
        invitation.update!(status: :accepted, accepted_at: Time.current)
      end

      it 'returns an error' do
        service = described_class.new(invitation, invited_user, token)
        result = service.call

        expect(result[:success]).to be false
        expect(result[:error]).to eq("Invitation has already been accepted.")
      end
    end

    context 'when token is invalid' do
      let(:invalid_token) { 'invalid_token' }

      it 'returns an error' do
        service = described_class.new(invitation, invited_user, invalid_token)
        result = service.call

        expect(result[:success]).to be false
        expect(result[:error]).to eq("Invalid invitation token.")
      end
    end

    context 'when invitation is not found' do
      it 'returns an error' do
        service = described_class.new(nil, invited_user, token)
        result = service.call

        expect(result[:success]).to be false
        expect(result[:error]).to eq("Invitation not found.")
      end
    end

    context 'when the invitation is a QR invite' do
      let(:qr_invitation) { create(:invitation, :qr, inviter: inviter) }

      it 'accepts any email' do
        result = described_class.new(qr_invitation, invited_user, qr_invitation.token).call

        expect(result[:success]).to be true
        expect(qr_invitation.reload.invited_user).to eq(invited_user)
        expect(invited_user.friends).to include(inviter)
      end

      it 'fails when another sign-up claimed it after it was loaded' do
        stale = Invitation.find(qr_invitation.id)
        described_class.new(qr_invitation, create(:user), qr_invitation.token).call

        result = described_class.new(stale, invited_user, stale.token).call

        expect(result[:success]).to be false
        expect(result[:error]).to eq("Invitation has already been accepted.")
        expect(invited_user.friends).not_to include(inviter)
      end
    end
  end
end
