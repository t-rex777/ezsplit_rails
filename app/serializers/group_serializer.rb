class GroupSerializer
  include JSONAPI::Serializer

  attributes :id, :name, :description, :created_by_id

  has_many :group_memberships
  has_many :users, through: :group_memberships
  belongs_to :created_by, serializer: :user
end
