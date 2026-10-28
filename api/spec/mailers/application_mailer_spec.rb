require "rails_helper"

RSpec.describe ApplicationMailer, type: :mailer do
  let(:user) { create(:user, email_address: "john.doe@example.com") }

  def with_env(vars)
    old = vars.keys.to_h { |k| [ k, ENV[k] ] }
    vars.each { |k, v| ENV[k] = v }
    yield
  ensure
    old.each { |k, v| ENV[k] = v }
  end

  it "sends from MAIL_FROM when it is set" do
    with_env("MAIL_FROM" => "EzSplit <hello@example.org>", "SMTP_USERNAME" => "me@gmail.com") do
      expect(UserMailer.welcome_email(user).from).to eq([ "hello@example.org" ])
    end
  end

  it "falls back to the SMTP account, which providers like Gmail require" do
    with_env("MAIL_FROM" => nil, "SMTP_USERNAME" => "me@gmail.com") do
      expect(UserMailer.welcome_email(user).from).to eq([ "me@gmail.com" ])
    end
  end

  it "uses the EzSplit address when neither is set" do
    with_env("MAIL_FROM" => nil, "SMTP_USERNAME" => nil) do
      expect(PasswordsMailer.reset(user).from).to eq([ "notifications@ezsplit.com" ])
    end
  end
end
