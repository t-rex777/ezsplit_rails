class Invitation < ApplicationRecord
  has_secure_token :token

  belongs_to :inviter, class_name: "User"
  belongs_to :invited_user, class_name: "User", optional: true

  enum :status, { pending: 0, accepted: 1, rejected: 2, expired: 3 }
  # A QR invite has no email: whoever signs up with it first uses their own.
  enum :kind, { email: 0, qr: 1 }, prefix: true

  validates :status, presence: true, inclusion: { in: statuses.keys }
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, unless: :kind_qr?
  validates :inviter, presence: true

  before_create :set_expiration

  def expired?
    expires_at.to_time < Time.now.to_time
  end

  def accepted?
    accepted_at.present?
  end

  def sent_to?(user)
    email.to_s.strip.casecmp?(user.email_address)
  end

  # The web page a link in the invite email, or a scanned QR code, opens.
  def registration_url
    base_url = Rails.application.routes.url_helpers.root_url(
      host: Rails.application.config.action_mailer.default_url_options[:host],
      port: Rails.application.config.action_mailer.default_url_options[:port]
    )
    url = "#{base_url}register?token=#{token}"
    email.present? ? "#{url}&email_address=#{email}" : url
  end

  private

  def set_expiration
    self.expires_at ||= Time.now + 7.days
  end
end
