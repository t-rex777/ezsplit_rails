class UserMailer < ApplicationMailer
  default from: "notifications@eszplit.com"

  def welcome_email(user)
    @user = user
    @app_name = "EZSplit"
    mail(to: @user.email_address, subject: "Welcome to #{@app_name}!")
  end

  def invitation_email(invitation)
    @invitation = invitation
    @inviter = invitation.inviter
    @invited_email = invitation.email
    @token = invitation.token
    @app_name = "EZSplit"

    # Generate registration URL with proper host handling
    base_url = Rails.application.routes.url_helpers.root_url(
      host: Rails.application.config.action_mailer.default_url_options[:host],
      port: Rails.application.config.action_mailer.default_url_options[:port]
    )
    @registration_url = "#{base_url}user_registers/new?token=#{@token}&email_address=#{@invited_email}"

    mail(to: @invited_email, subject: "You're invited to join #{@app_name}!")
  end
end
