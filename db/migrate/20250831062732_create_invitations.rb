class CreateInvitations < ActiveRecord::Migration[8.0]
  def change
    create_table :invitations do |t|
      t.string :email, null: false
      t.string :token, null: false
      t.references :inviter, null: false, foreign_key: { to_table: :users }
      t.references :invited_user, null: true, foreign_key: { to_table: :users }
      t.integer :status, default: 0
      t.text :message
      t.datetime :expires_at
      t.datetime :accepted_at

      t.timestamps
    end
    add_index :invitations, :email
    add_index :invitations, :token, unique: true
  end
end
