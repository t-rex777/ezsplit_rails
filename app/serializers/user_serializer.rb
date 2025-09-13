class UserSerializer
  include JSONAPI::Serializer

  attributes :id, :first_name, :last_name, :email_address, :phone, :avatar_url, :date_of_birth, :full_name

  has_many :groups, through: :group_memberships

  has_many :friends, serializer: UserSerializer do |user|
    user.all_friends
  end
end
