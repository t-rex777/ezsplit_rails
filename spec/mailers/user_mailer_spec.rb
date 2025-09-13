require "rails_helper"

RSpec.describe UserMailer, type: :mailer do
  describe "#welcome_email" do
    let(:user) { create(:user, first_name: "John", last_name: "Doe", email_address: "john.doe@example.com") }
    let(:mail) { UserMailer.welcome_email(user) }

    it "renders the headers" do
      expect(mail.subject).to eq("Welcome to EZSplit!")
      expect(mail.to).to eq([ user.email_address ])
      expect(mail.from).to eq([ "notifications@eszplit.com" ])
    end

    it "renders the body" do
      expect(mail.body.encoded).to match("Hello #{user.first_name}!")
      expect(mail.body.encoded).to match("Welcome to EZSplit!")
      expect(mail.body.encoded).to match("Split expenses with friends and family")
      expect(mail.body.encoded).to match("Track group spending easily")
      expect(mail.body.encoded).to match("Manage shared budgets efficiently")
      expect(mail.body.encoded).to match("Never lose track of who owes what")
    end

    it "includes the user's email address in the footer" do
      expect(mail.body.encoded).to match(user.email_address)
    end

    it "includes the app name in multiple places" do
      expect(mail.body.encoded.scan("EZSplit").length).to be >= 3
    end

    it "renders both HTML and text versions" do
      expect(mail.body.parts.length).to eq(2)

      html_part = mail.body.parts.find { |part| part.content_type.include?("text/html") }
      text_part = mail.body.parts.find { |part| part.content_type.include?("text/plain") }

      expect(html_part).to be_present
      expect(text_part).to be_present
    end

    it "has proper HTML structure" do
      html_part = mail.body.parts.find { |part| part.content_type.include?("text/html") }
      expect(html_part.body.encoded).to include("<h1>Welcome to EZSplit!</h1>")
      expect(html_part.body.encoded).to include("<h2>Hello #{user.first_name}!</h2>")
      expect(html_part.body.encoded).to include("<ul>")
      expect(html_part.body.encoded).to include("</ul>")
    end

    it "has proper text structure" do
      text_part = mail.body.parts.find { |part| part.content_type.include?("text/plain") }
      expect(text_part.body.encoded).to include("Welcome to EZSplit!")
      expect(text_part.body.encoded).to include("Hello #{user.first_name}!")
      expect(text_part.body.encoded).to include("- Split expenses with friends and family")
    end

    context "with different user names" do
      let(:user_with_special_chars) { create(:user, first_name: "José", last_name: "García-López", email_address: "jose@example.com") }
      let(:mail_special) { UserMailer.welcome_email(user_with_special_chars) }

      it "handles special characters in names" do
        # Check both HTML and text parts for the special character name
        html_part = mail_special.body.parts.find { |part| part.content_type.include?("text/html") }
        text_part = mail_special.body.parts.find { |part| part.content_type.include?("text/plain") }

        expect(html_part.body.encoded).to include("Hello #{user_with_special_chars.first_name}!")
        expect(text_part.body.encoded).to include("Hello #{user_with_special_chars.first_name}!")
      end
    end

    context "with different email addresses" do
      let(:user_with_plus_email) { create(:user, email_address: "user+test@example.com") }
      let(:mail_plus) { UserMailer.welcome_email(user_with_plus_email) }

      it "handles plus signs in email addresses" do
        expect(mail_plus.to).to eq([ user_with_plus_email.email_address ])
        # Check both HTML and text parts for the email address
        html_part = mail_plus.body.parts.find { |part| part.content_type.include?("text/html") }
        text_part = mail_plus.body.parts.find { |part| part.content_type.include?("text/plain") }

        expect(html_part.body.encoded).to include(user_with_plus_email.email_address)
        expect(text_part.body.encoded).to include(user_with_plus_email.email_address)
      end
    end
  end

  describe "email delivery" do
    let(:user) { create(:user) }

    it "can be delivered" do
      expect { UserMailer.welcome_email(user).deliver_now }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    it "can be delivered later" do
      expect { UserMailer.welcome_email(user).deliver_later }.to have_enqueued_mail(UserMailer, :welcome_email)
    end
  end

  describe "#invitation_email" do
    let(:inviter) { create(:user, first_name: "Jane", last_name: "Smith", email_address: "jane.smith@example.com") }
    let(:invitation) { create(:invitation, email: "friend@example.com", inviter: inviter, status: :pending) }
    let(:mail) { UserMailer.invitation_email(invitation) }

    it "renders the headers" do
      expect(mail.subject).to eq("You're invited to join EZSplit!")
      expect(mail.to).to eq([ invitation.email ])
      expect(mail.from).to eq([ "notifications@eszplit.com" ])
    end

    it "renders the body" do
      expect(mail.body.encoded).to match("You're Invited to EZSplit!")
      expect(mail.body.encoded).to match(inviter.first_name)
      expect(mail.body.encoded).to match(inviter.last_name)
      expect(mail.body.encoded).to match(invitation.email)
      expect(mail.body.encoded).to match("Split expenses with friends and family easily")
      expect(mail.body.encoded).to match("Track group spending and budgets")
      expect(mail.body.encoded).to match("Never lose track of who owes what")
      expect(mail.body.encoded).to match("Manage shared expenses efficiently")
    end

    it "includes the registration URL with token and email" do
      # Check both HTML and text parts for the registration URL
      html_part = mail.body.parts.find { |part| part.content_type.include?("text/html") }
      text_part = mail.body.parts.find { |part| part.content_type.include?("text/plain") }

      # The URL will be encoded in the email, so we check for the key parts
      expect(html_part.body.encoded).to include("register?token=#{invitation.token}")
      expect(html_part.body.encoded).to include("email_address=#{invitation.email}")
      expect(text_part.body.encoded).to include("register?token=#{invitation.token}")
      expect(text_part.body.encoded).to include("email_address=#{invitation.email}")
    end

    it "includes invitation expiry information" do
      expect(mail.body.encoded).to match("This invitation will expire in 7 days")
      expect(mail.body.encoded).to match(invitation.expires_at.strftime("%B %d, %Y at %I:%M %p"))
    end

    it "includes the app name in multiple places" do
      expect(mail.body.encoded.scan("EZSplit").length).to be >= 3
    end

    it "renders both HTML and text versions" do
      expect(mail.body.parts.length).to eq(2)

      html_part = mail.body.parts.find { |part| part.content_type.include?("text/html") }
      text_part = mail.body.parts.find { |part| part.content_type.include?("text/plain") }

      expect(html_part).to be_present
      expect(text_part).to be_present
    end

    it "has proper HTML structure" do
      html_part = mail.body.parts.find { |part| part.content_type.include?("text/html") }
      expect(html_part.body.encoded).to include("<h1>You're Invited to EZSplit!</h1>")
      expect(html_part.body.encoded).to include("<h2>Hello!</h2>")
      expect(html_part.body.encoded).to include("Accept Invitation & Create Account")
      expect(html_part.body.encoded).to include("class=\"button\"")
    end

    it "has proper text structure" do
      text_part = mail.body.parts.find { |part| part.content_type.include?("text/plain") }
      expect(text_part.body.encoded).to include("You're Invited to EZSplit!")
      expect(text_part.body.encoded).to include("Hello!")
      expect(text_part.body.encoded).to include("- Split expenses with friends and family easily")
    end

    context "with different inviter names" do
      let(:inviter_special) { create(:user, first_name: "José", last_name: "García-López", email_address: "jose@example.com") }
      let(:invitation_special) { create(:invitation, email: "friend@example.com", inviter: inviter_special) }
      let(:mail_special) { UserMailer.invitation_email(invitation_special) }

      it "handles special characters in inviter names" do
        html_part = mail_special.body.parts.find { |part| part.content_type.include?("text/html") }
        text_part = mail_special.body.parts.find { |part| part.content_type.include?("text/plain") }

        expect(html_part.body.encoded).to include(inviter_special.first_name)
        expect(html_part.body.encoded).to include(inviter_special.last_name)
        expect(text_part.body.encoded).to include(inviter_special.first_name)
        expect(text_part.body.encoded).to include(inviter_special.last_name)
      end
    end

    context "with different invited emails" do
      let(:invitation_plus) { create(:invitation, email: "user+test@example.com", inviter: inviter) }
      let(:mail_plus) { UserMailer.invitation_email(invitation_plus) }

      it "handles plus signs in email addresses" do
        expect(mail_plus.to).to eq([ invitation_plus.email ])
        html_part = mail_plus.body.parts.find { |part| part.content_type.include?("text/html") }
        text_part = mail_plus.body.parts.find { |part| part.content_type.include?("text/plain") }

        expect(html_part.body.encoded).to include(invitation_plus.email)
        expect(text_part.body.encoded).to include(invitation_plus.email)
      end
    end
  end

  describe "invitation email delivery" do
    let(:inviter) { create(:user) }
    let(:invitation) { create(:invitation, inviter: inviter) }

    it "can be delivered" do
      expect { UserMailer.invitation_email(invitation).deliver_now }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    it "can be delivered later" do
      expect { UserMailer.invitation_email(invitation).deliver_later }.to have_enqueued_mail(UserMailer, :invitation_email)
    end
  end
end
