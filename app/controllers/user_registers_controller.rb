class UserRegistersController < ApplicationController
  allow_unauthenticated_access only: %i[create new]

  def create
    @user = User.new(user_params)

    if @user.save
      UserMailer.welcome_email(@user).deliver_now

      # Handle invitation acceptance if token is provided
      if params[:token]
        handle_invitation_acceptance(@user, params[:token])
      end

      start_new_session_for(@user)
      render json: UserSerializer.new(@user).serializable_hash.to_json
    else
      render json: {
        status: :error,
        errors: @user.errors.full_messages,
        message: "Failed to create account"
      }, status: :unprocessable_entity
    end
  end

  private

  def handle_invitation_acceptance(user, token)
    # Find invitation by token
    invitation = Invitation.find_by(token: token)

    # Use the service to handle invitation acceptance
    service = InvitationAcceptanceService.new(invitation, user, token)
    result = service.call
        
    unless result[:success]
      Rails.logger.error "Failed to accept invitation: #{result[:error]}"
      # Note: We don't fail the user registration if invitation acceptance fails
      # The user is still created successfully, but the invitation remains pending
    end
  end

  def user_params
    params.require(:user).permit(
      :email_address,
      :password,
      :password_confirmation,
      :first_name,
      :last_name,
      :phone,
      :date_of_birth
    )
  end
end
