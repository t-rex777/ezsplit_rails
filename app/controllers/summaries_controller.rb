class SummariesController < ApplicationController
  CURRENCY = "INR"

  # GET /summary?month=YYYY-MM
  # My share of expenses dated in the month (INR), by category, plus my overall balances.
  def show
    month = parse_month(params[:month])
    if month.nil?
      render json: { errors: [ "Month must look like 2026-10" ] }, status: :unprocessable_entity
      return
    end

    shares = ExpensesUser.joins(:expense).where(
      user_id: current_user.id,
      expenses: { currency: CURRENCY, expense_date: month.all_month }
    )
    balances = balance_totals

    render json: {
      month: month.strftime("%Y-%m"),
      my_share: shares.sum(:amount).to_d.to_s("F"),
      you_owe: balances.dig(CURRENCY, :you_owe).to_s("F"),
      owed_to_you: balances.dig(CURRENCY, :owed_to_you).to_s("F"),
      categories: SpendingByCategory.rows(shares.pluck("expenses.category_id", "expenses_users.amount"), current_user),
      other_currencies: balances.except(CURRENCY).sort.map do |currency, totals|
        { currency: currency, you_owe: totals[:you_owe].to_s("F"), owed_to_you: totals[:owed_to_you].to_s("F") }
      end
    }
  end

  private

  def parse_month(value)
    return Date.current.beginning_of_month if value.blank?
    return nil unless value.to_s.match?(/\A\d{4}-\d{2}\z/)

    Date.strptime(value, "%Y-%m")
  rescue Date::Error
    nil
  end

  # { currency => { you_owe:, owed_to_you: } }, always including INR.
  def balance_totals
    totals = Hash.new { |hash, currency| hash[currency] = { you_owe: BigDecimal("0"), owed_to_you: BigDecimal("0") } }
    totals[CURRENCY]
    BalanceCalculator.for_user(current_user).each do |(_user_id, currency), amount|
      if amount.positive?
        totals[currency][:owed_to_you] += amount
      else
        totals[currency][:you_owe] -= amount
      end
    end
    totals
  end
end
