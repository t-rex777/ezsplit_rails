class AddUniqueIndexToGroupMembershipsAndFriendships < ActiveRecord::Migration[8.0]
  def change
    add_index :group_memberships, [ :group_id, :user_id ], unique: true
    add_index :friendships, [ :user_id, :friend_id ], unique: true
  end
end
