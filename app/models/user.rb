class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :group_memberships, dependent: :destroy
  has_many :groups, through: :group_memberships
  has_many :categories, dependent: :destroy
  has_many :groups, dependent: :destroy
  has_many :expenses, dependent: :destroy
  has_many :expenses_users, dependent: :destroy
  has_many :invitations, foreign_key: "inviter_id", dependent: :destroy
  has_many :invited_invitations, class_name: "Invitation", foreign_key: "invited_user_id", dependent: :destroy
  has_many :friendships, dependent: :destroy
  has_many :friends, through: :friendships

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, presence: true, length: { minimum: 6 }
  validates :first_name, :last_name, :phone, :date_of_birth, presence: true
end
