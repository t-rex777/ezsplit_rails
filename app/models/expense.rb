class Expense < ApplicationRecord
  belongs_to :payer, class_name: "User", foreign_key: :payer_id
  belongs_to :group, class_name: "Group", foreign_key: :group_id
  belongs_to :category, class_name: "Category", foreign_key: :category_id

  SPLIT_TYPES = %w[equal percentage exact].freeze
  CURRENCIES = %w[INR USD].freeze

  validates :name, :amount, :payer_id, :group_id, :category_id, :split_type, :currency, :expense_date, presence: true
  validates :split_type, inclusion: { in: SPLIT_TYPES, message: "must be equal, percentage or exact" }
  validates :currency, inclusion: { in: CURRENCIES, message: "must be INR or USD" }
end
