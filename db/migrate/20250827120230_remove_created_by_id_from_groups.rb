class RemoveCreatedByIdFromGroups < ActiveRecord::Migration[8.0]
  def change
    remove_column :groups, :created_by_id, :string
  end
end
