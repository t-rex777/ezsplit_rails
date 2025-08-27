class GroupSerializer
  include JSONAPI::Serializer

  attributes :name, :description

  has_many :group_memberships
  has_many :users, through: :group_memberships
end
