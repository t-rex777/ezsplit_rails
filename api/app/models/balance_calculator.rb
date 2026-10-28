# Works out who owes whom from expense shares and settlements.
#
# Everything is reduced to debts: "debtor owes creditor this amount in this currency".
# - An expense share is a debt from the share's user to the expense payer (the payer's own share is skipped).
# - A settlement where A pays B is a debt from B to A, which cancels what A owed B.
class BalanceCalculator
  Debt = Struct.new(:creditor_id, :debtor_id, :currency, :amount)

  # Net balance between `user` and each other person, per currency.
  # Returns { [other_user_id, currency] => BigDecimal }. Positive means the other person owes `user`.
  def self.for_user(user)
    shares = ExpensesUser.joins(:expense)
      .where("expenses.payer_id = :id OR expenses_users.user_id = :id", id: user.id)
    debts = debts_from(shares, Settlement.involving(user))

    debts.each_with_object(Hash.new(BigDecimal("0"))) do |debt, balances|
      if debt.creditor_id == user.id
        balances[[ debt.debtor_id, debt.currency ]] += debt.amount
      elsif debt.debtor_id == user.id
        balances[[ debt.creditor_id, debt.currency ]] -= debt.amount
      end
    end.reject { |_, amount| amount.zero? }
  end

  # Net position of each person inside a group, per currency.
  # Returns { [user_id, currency] => BigDecimal }. Positive means the group owes that person.
  def self.for_group(group)
    shares = ExpensesUser.joins(:expense).where(expenses: { group_id: group.id })
    debts = debts_from(shares, group.settlements)

    debts.each_with_object(Hash.new(BigDecimal("0"))) do |debt, balances|
      balances[[ debt.creditor_id, debt.currency ]] += debt.amount
      balances[[ debt.debtor_id, debt.currency ]] -= debt.amount
    end.reject { |_, amount| amount.zero? }
  end

  def self.debts_from(shares, settlements)
    share_rows = shares.where("expenses_users.user_id != expenses.payer_id")
      .pluck("expenses.payer_id", "expenses_users.user_id", "expenses.currency", "expenses_users.amount")
    settlement_rows = settlements.pluck(:payer_id, :payee_id, :currency, :amount)

    (share_rows + settlement_rows).map do |creditor_id, debtor_id, currency, amount|
      Debt.new(creditor_id, debtor_id, currency, BigDecimal(amount.to_s))
    end
  end
  private_class_method :debts_from
end
