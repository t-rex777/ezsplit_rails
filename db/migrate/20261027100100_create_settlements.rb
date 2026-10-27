class CreateSettlements < ActiveRecord::Migration[8.0]
  def change
    create_table :settlements do |t|
      t.references :payer, null: false, foreign_key: { to_table: :users }
      t.references :payee, null: false, foreign_key: { to_table: :users }
      t.references :group, foreign_key: true
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.string :currency, null: false
      t.string :notes
      t.date :settled_on, null: false

      t.timestamps
    end
  end
end
