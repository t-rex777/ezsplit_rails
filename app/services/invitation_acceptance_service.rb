class InvitationAcceptanceService
  class InvitationExpiredError < StandardError; end
  class InvitationAlreadyAcceptedError < StandardError; end
  class InvitationNotFoundError < StandardError; end
  class InvitationInvalidTokenError < StandardError; end

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
  end

  def update_invitation!
    @invitation.update!(
      invited_user: @invited_user,
      status: :accepted,
      accepted_at: Time.now
    )
  end

  def create_friendships!
    @invitation.invited_user.friendships.create!(friend: @invitation.inviter)
    @invitation.inviter.friendships.create!(friend: @invitation.invited_user)
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
