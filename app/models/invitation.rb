class Invitation < ApplicationRecord
  has_secure_token :token

  belongs_to :inviter, class_name: "User"
  belongs_to :invited_user, class_name: "User", optional: true

  enum :status, { pending: 0, accepted: 1, rejected: 2, expired: 3 }

  validates :status, presence: true, inclusion: { in: statuses.keys }
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :inviter, presence: true

  before_create :set_expiration

  def expired?
    expires_at.to_time < Time.now.to_time
  end

  def accepted?
    accepted_at.present?
  end

  private

  def set_expiration
    expires_at = Time.now + 7.days
  end
end
