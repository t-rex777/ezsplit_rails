class UserRegistersController < ApplicationController
  allow_unauthenticated_access only: %i[create new]

  def create
    @user = User.new(user_params)

    if @user.save
      UserMailer.welcome_email(@user).deliver_now

      if params[:token]
        redirect_to update_invitations_path(token: params[:token], email_address: @user.email_address)
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
