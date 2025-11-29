class UserSerializer
  include JSONAPI::Serializer

  attributes :id, :first_name, :last_name, :email_address, :phone, :avatar_url, :date_of_birth, :full_name


  attribute :expense_summary do |user, params|
    user.expense_summary if params && params[:current_user] && user.id == params[:current_user].id
  end

  has_many :groups, through: :group_memberships

  has_many :friends, serializer: UserSerializer do |user|
    user.all_friends
  end
end
