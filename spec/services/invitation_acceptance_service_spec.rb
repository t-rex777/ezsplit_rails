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
  end
end
