class CreatedByIdFromCategories < ActiveRecord::Migration[8.0]
  def change
    remove_column :categories, :created_by_id
  end
end
