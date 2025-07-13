class UserSerializer
  include JSONAPI::Serializer

  attributes :id, :first_name, :last_name, :email_address, :phone, :avatar_url, :date_of_birth

  has_many :groups, through: :group_memberships

  attribute :full_name do |user|
    "#{user.first_name} #{user.last_name}"
  end
end
