class CreateExpenses < ActiveRecord::Migration[8.0]
  def change
    create_table :expenses do |t|
      t.string :name
      t.string :notes
      t.decimal :amount
      t.string :currency
      t.references :payer, null: false, foreign_key: true
      t.references :group, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.string :split_type
      t.date :expense_date
      t.boolean :settled

      t.timestamps
    end
  end
end
