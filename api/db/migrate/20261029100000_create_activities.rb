class CreateActivities < ActiveRecord::Migration[8.0]
  def change
    # group_id and expense_id have no foreign keys so an entry outlives a deleted expense.
    create_table :activities do |t|
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.integer :group_id
      t.integer :expense_id
      t.string :action, null: false
      t.json :before_snapshot
      t.json :after_snapshot
      t.timestamps
    end
    add_index :activities, [ :group_id, :created_at ]
    add_index :activities, :expense_id

    create_table :activity_participants do |t|
      t.references :activity, null: false, foreign_key: true, index: false
      t.references :user, null: false, foreign_key: true
    end
    add_index :activity_participants, [ :activity_id, :user_id ], unique: true
  end
end
