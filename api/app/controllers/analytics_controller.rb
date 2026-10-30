class AnalyticsController < ApplicationController
  CURRENCY = "INR"
  SCOPES = %w[ all groups personal ].freeze

  before_action :set_scope

  # GET /analytics?scope=all|groups|personal
  # My share per month (INR), oldest first, from my first month with spending to this month.
  def show
    rows = shares.where(expenses: { currency: CURRENCY })
      .pluck("expenses.expense_date", "expenses.category_id", "expenses_users.amount")
    other_counts = shares.where.not(expenses: { currency: CURRENCY }).group("expenses.expense_date").count
      .each_with_object(Hash.new(0)) { |(date, count), totals| totals[date.beginning_of_month] += count }

    render json: { scope: @scope, months: months(rows, other_counts) }
  end

  # GET /analytics/expenses?month=YYYY-MM&category=food&scope=all
  # My INR expenses in one month whose category has this name (any case), newest first.
  def expenses
    month = parse_month(params[:month])
    if month.nil?
      render json: { errors: [ "Month must look like 2026-10" ] }, status: :unprocessable_entity
      return
    end

    rows = shares.joins(expense: :category)
      .where(expenses: { currency: CURRENCY, expense_date: month.all_month })
      .where("LOWER(categories.name) = ?", params[:category].to_s.downcase)
      .includes(expense: :group)
      .order("expenses.expense_date DESC, expenses.id DESC")

    render json: {
      expenses: rows.map do |share|
        expense = share.expense
        { id: expense.id, name: expense.name, expense_date: expense.expense_date.to_s,
          group_name: expense.group&.name, my_share: share.amount.to_d.to_s("F") }
      end
    }
  end

  private

  def set_scope
    @scope = params[:scope].presence || "all"
    return if SCOPES.include?(@scope)

    render json: { errors: [ "Scope must be all, groups or personal" ] }, status: :unprocessable_entity
  end

  # My shares, limited to the scope.
  def shares
    scoped = ExpensesUser.joins(:expense).where(user_id: current_user.id)
    case @scope
    when "groups" then scoped.where.not(expenses: { group_id: nil })
    when "personal" then scoped.where(expense_id: Expense.personal_for(current_user).select(:id))
    else scoped
    end
  end

  def months(rows, other_counts)
    return [] if rows.empty?

    categories = Category.where(id: rows.map(&:second).uniq).index_by(&:id)
    own = SpendingByCategory.own_by_name(current_user)
    by_month = rows.group_by { |date, _, _| date.beginning_of_month }

    month = by_month.keys.min
    last = Date.current.beginning_of_month
    result = []
    while month <= last
      pairs = (by_month[month] || []).map { |_, category_id, amount| [ category_id, amount ] }
      result << {
        month: month.strftime("%Y-%m"),
        total: pairs.sum(BigDecimal("0")) { |_, amount| BigDecimal(amount.to_s) }.to_s("F"),
        other_currency_count: other_counts[month],
        categories: SpendingByCategory.rows(pairs, current_user, categories: categories, own: own)
      }
      month = month.next_month
    end
    result
  end

  def parse_month(value)
    return nil unless value.to_s.match?(/\A\d{4}-\d{2}\z/)

    Date.strptime(value, "%Y-%m")
  rescue Date::Error
    nil
  end
end
