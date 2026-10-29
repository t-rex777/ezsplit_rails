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

  attr_writer :last_activity_at, :balances, :expense_summary

  # Loads everything GroupSerializer reads for many groups in a fixed number of queries,
  # instead of about 9 queries per group.
  def self.preload_for_serializer(groups, user = Current.user)
    groups = Array(groups).compact
    return if groups.empty?

    ActiveRecord::Associations::Preloader.new(records: groups, associations: [ :group_memberships, :users ]).call
    ids = groups.map(&:id).uniq
    last_expense = Expense.where(group_id: ids).group(:group_id).maximum(:updated_at)
    last_settlement = Settlement.where(group_id: ids).group(:group_id).maximum(:created_at)
    balances = BalanceCalculator.for_groups(ids)
    summaries = expense_summaries(ids, user)

    groups.each do |group|
      group.last_activity_at = [ group.updated_at, last_expense[group.id], last_settlement[group.id] ].compact.max
      group.balances = balances[group.id]
      group.expense_summary = summaries[group.id]
    end
  end

  # expense_summary for many groups in 5 queries. Returns { group_id => summary }.
  def self.expense_summaries(ids, user)
    scope = Expense.where(group_id: ids).group(:group_id)
    counts = scope.count
    totals = scope.sum(:amount)
    paid = scope.where(payer_id: user.id).sum(:amount)
    owed = scope.joins(:expenses_users).where(expenses_users: { user_id: user.id }).sum("expenses_users.amount")
    currencies = Expense.where(id: scope.select("MIN(expenses.id)")).pluck(:group_id, :currency).to_h

    ids.index_with do |id|
      total_paid = paid.fetch(id, BigDecimal(0))
      total_owed = owed.fetch(id, BigDecimal(0))
      {
        total_expenses: counts.fetch(id, 0),
        total_amount: totals.fetch(id, BigDecimal(0)),
        current_user_balance: {
          total_paid: total_paid,
          total_owed: total_owed,
          net_balance: total_paid - total_owed,
          status: total_paid > total_owed ? "lent" : "owes"
        },
        currency: currencies[id]
      }
    end
  end

  def last_activity_at
    @last_activity_at || [ updated_at, expenses.maximum(:updated_at), settlements.maximum(:created_at) ].compact.max
  end

  # The user's net in this group, per currency. Positive means the group owes them.
  def net_for(user, currency)
    (@balances || BalanceCalculator.for_group(self)).fetch([ user.id, currency ], BigDecimal("0"))
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
    @expense_summary || {
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
