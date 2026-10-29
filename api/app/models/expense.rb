class Expense < ApplicationRecord
  belongs_to :payer, class_name: "User", foreign_key: :payer_id
  belongs_to :group, class_name: "Group", foreign_key: :group_id, optional: true
  belongs_to :category, class_name: "Category", foreign_key: :category_id
  has_many :expenses_users, dependent: :destroy
  belongs_to :user

  SPLIT_TYPES = %w[equal percentage exact].freeze
  CURRENCIES = %w[INR USD].freeze

  validates :name, :amount, :payer_id, :category_id, :split_type, :currency, :expense_date, presence: true
  validates :amount, numericality: { greater_than: 0 }, allow_nil: true
  validates :split_type, inclusion: { in: SPLIT_TYPES, message: "must be equal, percentage or exact" }
  validates :currency, inclusion: { in: CURRENCIES, message: "must be INR or USD" }

  # A copy of the expense for the activity log. Names are copied in so the entry still reads after a delete.
  # Shares are read with a fresh query, so the copy is right even after the split was just rebuilt.
  def snapshot
    {
      "name" => name,
      "amount" => amount.to_s,
      "currency" => currency,
      "expense_date" => expense_date.to_s,
      "split_type" => split_type,
      "notes" => notes,
      "creator_id" => user_id,
      "category" => { "id" => category.id, "name" => category.name, "icon" => category.icon, "color" => category.color },
      "payer" => { "id" => payer.id, "name" => payer.full_name },
      "group" => group && { "id" => group.id, "name" => group.name },
      "shares" => expenses_users.includes(:user).order(:user_id).map do |share|
        { "user_id" => share.user_id, "name" => share.user.full_name, "amount" => share.amount.to_s }
      end
    }
  end

  def current_user_amount
    # Sums in Ruby so a preloaded expenses_users list costs no extra query.
    amount = expenses_users.select { |share| share.user_id == Current.user.id }.sum(BigDecimal(0), &:amount)
    payer_id == Current.user.id ? amount : -amount
  end
end
