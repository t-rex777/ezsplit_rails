class InvitationsController < ApplicationController
  allow_unauthenticated_access only: %i[update]
  before_action :set_invitation, :verify_invitation_status, only: [ :update ]
  before_action :set_invited_user, only: [ :create, :update ]

  class InvitationExpiredError < StandardError; end
  class InvitationAlreadyAcceptedError < StandardError; end
  class InvitationNotFoundError < StandardError; end
  class InvitationInvalidTokenError < StandardError; end

  rescue_from InvitationNotFoundError, with: :render_invitation_not_found
  rescue_from InvitationExpiredError, with: :render_invitation_expired
  rescue_from InvitationAlreadyAcceptedError, with: :render_invitation_already_accepted
  rescue_from InvitationInvalidTokenError, with: :render_invitation_invalid_token

  # if user present -> just create an invitation and add to friends list
  # if not present -> TBD

  # POST /invitations
  def create
    if @invited_user.present?
      if @invited_user.friends.include?(current_user)
        render json: { message: "#{@invited_user.full_name} is already a friend." }
        return
      end

      ActiveRecord::Base.transaction do
        invitation_params = {
          email: create_invitation_params[:email_address],
          inviter: current_user,
          invited_user: @invited_user,
          status: :accepted,
          accepted_at: Time.now
        }

        @invitation = current_user.invitations.new(invitation_params)
        @invitation.invited_user.friendships.create!(friend: @invitation.inviter)
      end

      if @invitation.save
        render json: { message: "#{@invited_user.full_name} added as friend." }, status: :created
        return
      end
    end

    @invitation = current_user.invitations.new(
      email: create_invitation_params[:email_address],
      inviter: current_user
    )

    if @invitation.save
      # Send invitation email
      UserMailer.invitation_email(@invitation).deliver_now
      render json: { message: "Invitation sent successfully." }, status: :created
    else
      render json: { errors: @invitation.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PUT /invitations/:id
  def update
    if @invited_user.nil?
      render json: { message: "User not found. Please create a new account." }, status: :not_found
      return
    end

    begin
      ActiveRecord::Base.transaction do
        params = {
          **update_invitation_params.except(:email_address),
           invited_user: @invited_user,
           status: :accepted,
          accepted_at: Time.now
            }

        @invitation.update!(params)
        @invitation.invited_user.friendships.create!(friend: @invitation.inviter)
      end

      render json: { message: "User invited successfully." }, status: :ok
    rescue ActiveRecord::RecordInvalid => e
      render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def verify_invitation_status
    raise InvitationNotFoundError if @invitation.nil?
    raise InvitationExpiredError if @invitation.expired?
    raise InvitationAlreadyAcceptedError if @invitation.accepted?
    raise InvitationInvalidTokenError if @invitation.token != update_invitation_params[:token]
  end

  def set_invited_user
    @invited_user = User.find_by_email_address(update_invitation_params[:email_address])
  end

  def set_invitation
    @invitation = Invitation.find_by(id: params[:id])
  end

  def create_invitation_params
    params.require(:invitation).permit(:email_address, :message)
  end

  def update_invitation_params
    params.require(:invitation).permit(:token, :email_address)
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
