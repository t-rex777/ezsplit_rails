class DropCreateJoinTableExpensesUsers < ActiveRecord::Migration[8.0]
  def change
    drop_table :create_join_table_expenses_users
  end
end
