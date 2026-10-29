class Group < ApplicationRecord
  belongs_to :user
  has_many :group_memberships, dependent: :destroy
  has_many :users, through: :group_memberships

  validates :name, presence: true

  # Get all expenses for this group
  def expenses
    Expense.where(group_id: id)
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

  attr_writer :expense_summary

  # Fills expense_summary for many groups with 5 queries in total instead of 5 per group.
  # Groups without expenses keep the per-group path so their behaviour does not change.
  def self.preload_expense_summaries(groups, user = Current.user)
    groups = groups.compact
    return if groups.empty? || user.nil?

    ids = groups.map(&:id).uniq
    scope = Expense.where(group_id: ids).group(:group_id)
    counts = scope.count
    totals = scope.sum(:amount)
    paid = scope.where(payer_id: user.id).sum(:amount)
    owed = scope.joins(:expenses_users).where(expenses_users: { user_id: user.id }).sum("expenses_users.amount")
    currencies = Expense.where(id: scope.select("MIN(expenses.id)")).pluck(:group_id, :currency).to_h

    groups.each do |group|
      next unless counts.key?(group.id)

      total_paid = paid.fetch(group.id, BigDecimal(0))
      total_owed = owed.fetch(group.id, BigDecimal(0))
      group.expense_summary = {
        total_expenses: counts[group.id],
        total_amount: totals[group.id],
        current_user_balance: {
          total_paid: total_paid,
          total_owed: total_owed,
          net_balance: total_paid - total_owed,
          status: total_paid > total_owed ? "lent" : "owes"
        },
        currency: currencies[group.id]
      }
    end
  end

  # Get summary statistics for the group
  def expense_summary
    @expense_summary ||= {
      total_expenses: expenses.count,
      total_amount: expenses.sum(:amount),
      current_user_balance: current_user_balance,
      # todo: this will fail if first expense and other expenses has different currencies
      # but this is just a temporary solution to get the currency
      currency: expenses.first.currency
    }
  end
end
