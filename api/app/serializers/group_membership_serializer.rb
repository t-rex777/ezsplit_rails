class GroupMembershipSerializer
  include JSONAPI::Serializer

  attributes :id, :user_id, :group_id, :joined_at, :left_at

  belongs_to :user
  belongs_to :group

  attribute :active do |membership|
    membership.left_at.nil?
  end
end
