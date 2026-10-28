class AllowExpensesWithoutGroup < ActiveRecord::Migration[8.0]
  def change
    change_column_null :expenses, :group_id, true
  end
end
