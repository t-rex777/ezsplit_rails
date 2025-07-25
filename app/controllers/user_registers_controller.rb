class UserRegistersController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    respond_to do |format|
      if @user.save
        start_new_session_for(@user)

        format.json do
          render json: UserSerializer.new(@user).serializable_hash.to_json
        end
        format.html { redirect_to after_authentication_url, notice: "Welcome! You have signed up successfully." }
      else
        format.json do
          render json: {
            status: :error,
            errors: @user.errors.full_messages,
            message: "Failed to create account"
          }, status: :unprocessable_entity
        end
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  private

  def user_params
    params.require(:user).permit(:email_address, :password, :password_confirmation, :first_name, :last_name, :phone, :date_of_birth)
  end
end
