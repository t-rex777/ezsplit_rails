class Settlement < ApplicationRecord
  belongs_to :payer, class_name: "User"
  belongs_to :payee, class_name: "User"
  belongs_to :group, optional: true

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :currency, inclusion: { in: Expense::CURRENCIES, message: "must be INR or USD" }
  validates :settled_on, presence: true
  validate :payee_is_not_payer

  before_validation { self.settled_on ||= Date.current }

  scope :involving, ->(user) { where(payer_id: user.id).or(where(payee_id: user.id)) }

  private

  def payee_is_not_payer
    errors.add(:payee, "can't be the same as the payer") if payer_id.present? && payer_id == payee_id
  end
end
