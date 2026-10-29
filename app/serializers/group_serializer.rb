class GroupSerializer
  include JSONAPI::Serializer

  attributes :name, :description, :expense_summary

  has_many :group_memberships
  has_many :users, through: :group_memberships
end
