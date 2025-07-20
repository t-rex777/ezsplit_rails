class AddCreatedByIdToCategories < ActiveRecord::Migration[8.0]
  def change
    add_column :categories, :created_by_id, :integer, null: false
    add_foreign_key :categories, :users, column: :created_by_id
    add_index :categories, :created_by_id
  end
end
