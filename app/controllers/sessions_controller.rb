class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_url, alert: "Try again later." }

  def new
  end

  def create
    permitted_params = params.permit(:email_address, :password)
    Rails.logger.info "Login attempt with: #{permitted_params.inspect}"

    user = User.find_by(email_address: permitted_params[:email_address])
    Rails.logger.info "User found: #{user&.email_address || 'No user found'}"

    if user = User.authenticate_by(permitted_params)
      Rails.logger.info "Authentication successful: #{user.email_address}"
      start_new_session_for user
      redirect_to after_authentication_url
    else
      Rails.logger.info "Authentication failed"
      redirect_to new_session_path, alert: "Try another email address or password."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path
  end
end
