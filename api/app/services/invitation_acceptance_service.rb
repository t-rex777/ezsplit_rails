class InvitationAcceptanceService
  class InvitationExpiredError < StandardError; end
  class InvitationAlreadyAcceptedError < StandardError; end
  class InvitationNotFoundError < StandardError; end
  class InvitationInvalidTokenError < StandardError; end
  class InvitationEmailMismatchError < StandardError; end

  def initialize(invitation, invited_user, token)
    @invitation = invitation
    @invited_user = invited_user
    @token = token
  end

  def call
    validate_invitation!

    ActiveRecord::Base.transaction do
      update_invitation!
      create_friendships!
    end

    { success: true, message: "User invited successfully." }
  rescue StandardError => e
    { success: false, error: e.message }
  end

  private

  def validate_invitation!
    raise InvitationNotFoundError, "Invitation not found." if @invitation.nil?
    raise InvitationExpiredError, "Invitation has expired." if @invitation.expired?
    raise InvitationAlreadyAcceptedError, "Invitation has already been accepted." if @invitation.accepted?
    raise InvitationInvalidTokenError, "Invalid invitation token." if @invitation.token != @token
    return if @invitation.kind_qr?
    raise InvitationEmailMismatchError, "This invitation was sent to a different email address." unless @invitation.sent_to?(@invited_user)
  end

  # A conditional update, so two sign-ups racing on one QR code can't both claim it.
  def update_invitation!
    now = Time.current
    claimed = Invitation.pending.where(id: @invitation.id, accepted_at: nil).where("expires_at > ?", now)
                        .update_all(invited_user_id: @invited_user.id, status: Invitation.statuses[:accepted],
                                    accepted_at: now, updated_at: now)
    raise InvitationAlreadyAcceptedError, "Invitation has already been accepted." unless claimed == 1

    @invitation.reload
  end

  def create_friendships!
    Friendship.find_or_create_by!(user: @invitation.invited_user, friend: @invitation.inviter)
    Friendship.find_or_create_by!(user: @invitation.inviter, friend: @invitation.invited_user)
  end

  def render_invitation_not_found
    render json: { message: "Invitation not found." }, status: :not_found
  end

  def render_invitation_expired
    render json: { message: "Invitation has expired." }, status: :unprocessable_entity
  end

  def render_invitation_already_accepted
    render json: { message: "Invitation has already been accepted." }, status: :unprocessable_entity
  end

  def render_invitation_invalid_token
    render json: { message: "Invalid invitation token." }, status: :unprocessable_entity
  end
end
