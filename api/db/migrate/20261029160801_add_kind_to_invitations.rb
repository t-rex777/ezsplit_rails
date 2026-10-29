class AddKindToInvitations < ActiveRecord::Migration[8.0]
  def change
    add_column :invitations, :kind, :integer, default: 0, null: false
    change_column_null :invitations, :email, true
  end
end
