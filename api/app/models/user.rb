class User < ApplicationRecord
  # Icons are keys in the app's CategoryIcon map; colors come from its category color picker.
  DEFAULT_CATEGORIES = [
    { name: "Grocery", icon: "shopping_cart", color: "#5DCAA5" },
    { name: "Travel", icon: "flight", color: "#B5D4F4" },
    { name: "Entertainment", icon: "movie", color: "#AFA9EC" },
    { name: "Dining", icon: "restaurant", color: "#FAC775" },
    { name: "Personal Care", icon: "favorite", color: "#F4C0D1" }
  ].freeze

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :group_memberships, dependent: :destroy
  has_many :active_group_memberships, -> { where(left_at: nil) }, class_name: "GroupMembership"
  has_many :groups, through: :active_group_memberships
  has_many :owned_groups, class_name: "Group", dependent: :destroy
  has_many :categories, dependent: :destroy
  has_many :expenses, dependent: :destroy
  has_many :expenses_users, dependent: :destroy
  has_many :invitations, foreign_key: "inviter_id", dependent: :destroy
  has_many :invited_invitations, class_name: "Invitation", foreign_key: "invited_user_id", dependent: :destroy
  has_many :friendships, dependent: :destroy
  has_many :inverse_friendships, class_name: "Friendship", foreign_key: "friend_id", dependent: :destroy
  has_many :friends, through: :friendships, source: :friend
  has_many :inverse_friends, through: :inverse_friendships, source: :user
  has_many :settlements_paid, class_name: "Settlement", foreign_key: :payer_id, dependent: :destroy
  has_many :settlements_received, class_name: "Settlement", foreign_key: :payee_id, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  # has_secure_password already requires a password on create; this lets profile updates skip it.
  validates :password, length: { minimum: 6 }, allow_nil: true
  validates :first_name, :last_name, :phone, :date_of_birth, presence: true

  after_create :create_default_categories

  def full_name
    "#{first_name} #{last_name}"
  end

  def all_friends
    User.where(id: friendships.select(:friend_id))
        .or(User.where(id: inverse_friendships.select(:user_id)))
  end

  attr_writer :serialized_friends

  # all_friends for UserSerializer; an array when preloaded, so callers that need a relation keep using all_friends.
  def serialized_friends
    @serialized_friends || all_friends
  end

  # Loads what UserSerializer reads (group ids and friends) for many users in 4 queries instead of 2 per user.
  def self.preload_for_serializer(users)
    users = Array(users).compact
    return if users.empty?

    ActiveRecord::Associations::Preloader.new(records: users, associations: :groups).call
    ids = users.map(&:id).uniq
    pairs = Friendship.where(user_id: ids).or(Friendship.where(friend_id: ids)).pluck(:user_id, :friend_id)
    friend_ids = Hash.new { |hash, key| hash[key] = [] }
    pairs.each do |user_id, friend_id|
      friend_ids[user_id] << friend_id
      friend_ids[friend_id] << user_id
    end
    friends_by_id = User.where(id: friend_ids.values_at(*ids).flatten.uniq).index_by(&:id)

    users.each do |user|
      # Sorted by id to match the row order SQLite returns for the all_friends query.
      user.serialized_friends = friend_ids[user.id].uniq.sort.filter_map { |id| friends_by_id[id] }
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
      currency: expenses.first&.currency
    }
  end

  def friend_ids_with_self
    all_friends.ids + [ id ]
  end

  # Expenses this user created, paid for, or has a share in.
  def visible_expenses
    Expense.where(user_id: id)
      .or(Expense.where(payer_id: id))
      .or(Expense.where(id: ExpensesUser.where(user_id: id).select(:expense_id)))
  end

  private

  def create_default_categories
    categories.create!(DEFAULT_CATEGORIES)
  end
end
