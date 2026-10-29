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

  attr_writer :preloaded_friends

  def all_friends
    @preloaded_friends || User.where(id: friendships.select(:friend_id))
                              .or(User.where(id: inverse_friendships.select(:user_id)))
  end

  # Fills all_friends for many users with 2 queries in total instead of 1 per user.
  def self.preload_friends(users)
    users = users.compact
    return if users.empty?

    ids = users.map(&:id).uniq
    pairs = Friendship.where(user_id: ids).or(Friendship.where(friend_id: ids)).pluck(:user_id, :friend_id)
    friend_ids = Hash.new { |h, k| h[k] = [] }
    pairs.each do |user_id, friend_id|
      friend_ids[user_id] << friend_id
      friend_ids[friend_id] << user_id
    end
    friends_by_id = User.where(id: friend_ids.values_at(*ids).flatten.uniq).index_by(&:id)

    users.each do |user|
      # Sorted by id to match the row order SQLite returns for the all_friends query.
      user.preloaded_friends = friend_ids[user.id].uniq.sort.filter_map { |id| friends_by_id[id] }
    end
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
