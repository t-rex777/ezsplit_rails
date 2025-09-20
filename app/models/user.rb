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
  has_many :inverse_friendships, class_name: "Friendship", foreign_key: "friend_id", dependent: :destroy
  has_many :friends, through: :friendships, source: :friend
  has_many :inverse_friends, through: :inverse_friendships, source: :user

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, presence: true, length: { minimum: 6 }
  validates :first_name, :last_name, :phone, :date_of_birth, presence: true

  def full_name
    "#{first_name} #{last_name}"
  end

  def all_friends
    User.where(id: friendships.select(:friend_id))
        .or(User.where(id: inverse_friendships.select(:user_id)))
  end
end
