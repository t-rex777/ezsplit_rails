class AddSettlementIdToActivities < ActiveRecord::Migration[8.0]
  def change
    # No foreign key, like expense_id, so the entry outlives a deleted settlement.
    add_column :activities, :settlement_id, :integer
    add_index :activities, :settlement_id
  end
end
