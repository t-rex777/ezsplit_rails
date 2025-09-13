class ExpensesUserSerializer
  include JSONAPI::Serializer
  attributes :paid, :amount, :expense_id, :user_id
  belongs_to :user, serializer: UserSerializer
  belongs_to :expense, serializer: ExpenseSerializer
end
