# Preview all emails at http://localhost:3000/rails/mailers/user_mailer
class UserMailerPreview < ActionMailer::Preview
  def welcome_email
    # Create a sample user for preview
    user = User.new(
      first_name: "John",
      last_name: "Doe",
      email_address: "john.doe@example.com",
      phone: "+1234567890",
      date_of_birth: Date.new(1990, 1, 1)
    )

    UserMailer.welcome_email(user)
  end

  def invitation_email
    # Create sample users and invitation for preview
    inviter = User.new(
      first_name: "Jane",
      last_name: "Smith",
      email_address: "jane.smith@example.com",
      phone: "+1234567890",
      date_of_birth: Date.new(1985, 5, 15)
    )

    invitation = Invitation.new(
      email: "friend@example.com",
      inviter: inviter,
      token: "sample_token_123456",
      status: :pending,
      expires_at: 7.days.from_now
    )

    UserMailer.invitation_email(invitation)
  end
end
