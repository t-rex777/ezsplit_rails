class PasswordsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_user_by_token, only: %i[ edit update ]

  def new
  end

  def create
    respond_to do |format|
      if user = User.find_by(email_address: params[:email_address])
        PasswordsMailer.reset(user).deliver_later
        format.json do
          render json: {
            status: :success,
            message: "Password reset instructions sent to your email"
          }
        end
        format.html { redirect_to new_session_path, notice: "Password reset instructions sent (if user with that email address exists)." }
      else
        format.json do
          render json: {
            status: :success, # Still return success to prevent email enumeration
            message: "Password reset instructions sent to your email"
          }
        end
        format.html { redirect_to new_session_path, notice: "Password reset instructions sent (if user with that email address exists)." }
      end
    end
  end

  def edit
  end

  def update
    respond_to do |format|
      if @user.update(params.permit(:password, :password_confirmation))
        format.json do
          render json: {
            status: :success,
            message: "Password has been reset successfully"
          }
        end
        format.html { redirect_to new_session_path, notice: "Password has been reset." }
      else
        format.json do
          render json: {
            status: :error,
            errors: @user.errors.full_messages,
            message: "Failed to reset password"
          }, status: :unprocessable_entity
        end
        format.html { redirect_to edit_password_path(params[:token]), alert: "Passwords did not match." }
      end
    end
  end

  private
    def set_user_by_token
      @user = User.find_by_password_reset_token!(params[:token])
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      respond_to do |format|
        format.json do
          render json: {
            status: :error,
            errors: [ "Invalid or expired reset token" ],
            message: "Password reset link is invalid or has expired"
          }, status: :unauthorized
        end
        format.html { redirect_to new_password_path, alert: "Password reset link is invalid or has expired." }
      end
    end
end
