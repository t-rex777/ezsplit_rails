class GroupSerializer
  include JSONAPI::Serializer

  attributes :name, :description, :expense_summary, :last_activity_at
  attribute(:owner_id) { |group| group.user_id }
  attribute(:my_net) { |group| group.net_for(Current.user, "INR").to_s("F") if Current.user }

  has_many :group_memberships
  has_many :users, through: :group_memberships
end
