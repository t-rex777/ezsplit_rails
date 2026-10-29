class UserMailer < ApplicationMailer
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
    @registration_url = invitation.registration_url

    mail(to: @invited_email, subject: "You're invited to join #{@app_name}!")
  end

  def friend_request_email(invitation)
    @inviter = invitation.inviter
    mail(to: invitation.email, subject: "#{@inviter.full_name} wants to add you as a friend on EZSplit")
  end
end
