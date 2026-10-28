class ExpensesUser < ApplicationRecord
  belongs_to :expense
  belongs_to :user

  validates :amount, :user_id, :expense_id, presence: true

  before_validation :set_paid, unless: :paid_set?

  private

  def paid_set?
    !paid.nil?
  end

  def set_paid
    return unless expense&.payer_id && user_id
    self.paid = expense.payer_id.to_s == user_id.to_s
  end
end
