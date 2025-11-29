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

  # Get all expenses with includes for better performance
  def all_expenses
    expenses.includes(:payer, :category, :expenses_users)
  end

  # Calculate current user's balance in this group
  def current_user_balance
    total_paid = expenses.where(payer_id: Current.user.id).sum(:amount)
    total_owed = expenses.joins(:expenses_users)
                        .where(expenses_users: { user_id: Current.user.id })
                        .sum("expenses_users.amount")

    {
      total_paid: total_paid,
      total_owed: total_owed,
      net_balance: total_paid - total_owed,
      status: total_paid > total_owed ? "lent" : "owes"
    }
  end

  # Get summary statistics for the group
  def expense_summary
    {
      total_expenses: expenses.count,
      total_amount: expenses.sum(:amount),
      current_user_balance: current_user_balance,
      # todo: this will fail if first expense and other expenses has different currencies
      # but this is just a temporary solution to get the currency
      currency: expenses.first.currency
    }
  end
end
