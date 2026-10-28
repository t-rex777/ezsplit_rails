class ApplicationMailer < ActionMailer::Base
  # Providers such as Gmail only send as the signed-in account, so fall back to it.
  default from: -> { ENV["MAIL_FROM"].presence || ENV["SMTP_USERNAME"].presence || "EzSplit <notifications@ezsplit.com>" }
  layout "mailer"
end
