class UserRegistersController < ApplicationController
  allow_unauthenticated_access only: %i[create new]

  INVITE_REQUIRED = "A valid invite is required to sign up".freeze
  QR_INVITE_USED = "This invite has already been used. Ask your friend for a new one.".freeze
  QR_INVITE_EXPIRED = "This invite has expired. Ask your friend for a new one.".freeze

  # POST /user_registers
  # ezsplit is invite only: sign-up needs a pending invite sent to the same email,
  # or an unused QR invite, which takes any email.
  def create
    @user = User.new(user_params)
    invitation = Invitation.find_by(token: params[:token]) if params[:token].present?

    if (problem = invite_problem(invitation, @user))
      render json: { status: :error, errors: [ problem ], message: "Failed to create account" }, status: :unprocessable_entity
      return
    end

    ActiveRecord::Base.transaction do
      @user.save!
      result = InvitationAcceptanceService.new(invitation, @user, params[:token]).call
      raise ActiveRecord::Rollback, result[:error] unless result[:success]
    end

    if @user.persisted?
      UserMailer.welcome_email(@user).deliver_now
      start_new_session_for(@user)
      render json: UserSerializer.new(@user).serializable_hash.to_json
    else
      render json: {
        status: :error,
        errors: @user.errors.full_messages.presence || [ invitation.kind_qr? ? QR_INVITE_USED : INVITE_REQUIRED ],
        message: "Failed to create account"
      }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordInvalid
    render json: { status: :error, errors: @user.errors.full_messages, message: "Failed to create account" }, status: :unprocessable_entity
  end

  private

  def invite_problem(invitation, user)
    return INVITE_REQUIRED if invitation.nil?

    if invitation.kind_qr?
      return QR_INVITE_USED unless invitation.pending?
      return QR_INVITE_EXPIRED if invitation.expired?
      return
    end

    INVITE_REQUIRED unless invitation.pending? && !invitation.expired? && invitation.sent_to?(user)
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
