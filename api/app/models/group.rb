class Group < ApplicationRecord
  belongs_to :user
  has_many :group_memberships, dependent: :destroy
  has_many :active_memberships, -> { where(left_at: nil) }, class_name: "GroupMembership"
  has_many :users, through: :active_memberships
  has_many :expenses, dependent: :restrict_with_error
  has_many :settlements, dependent: :restrict_with_error

  validates :name, presence: true

  # Latest of: the group itself changing, an expense changing, or a settlement being recorded.
  ACTIVITY_SQL = <<~SQL.squish.freeze
    MAX(groups.updated_at,
        COALESCE((SELECT MAX(expenses.updated_at) FROM expenses WHERE expenses.group_id = groups.id), groups.updated_at),
        COALESCE((SELECT MAX(settlements.created_at) FROM settlements WHERE settlements.group_id = groups.id), groups.updated_at))
  SQL

  def last_activity_at
    [ updated_at, expenses.maximum(:updated_at), settlements.maximum(:created_at) ].compact.max
  end

  # The user's net in this group, per currency. Positive means the group owes them.
  def net_for(user, currency)
    BalanceCalculator.for_group(self).fetch([ user.id, currency ], BigDecimal("0"))
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

  def owner?(user)
    user_id == user.id
  end
end
