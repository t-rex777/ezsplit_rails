class ExpenseSerializer
  include JSONAPI::Serializer
  attributes :name, :amount, :split_type, :currency, :expense_date, :settled
  belongs_to :payer, serializer: UserSerializer
  belongs_to :group, serializer: GroupSerializer
  belongs_to :category, serializer: CategorySerializer
  has_many :expenses_users, serializer: ExpensesUserSerializer
end
