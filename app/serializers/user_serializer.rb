class UserSerializer
  include JSONAPI::Serializer

  # What other users may see. Phone and date of birth stay private.
  PUBLIC_FIELDS = %i[id first_name last_name full_name email_address avatar_url groups].freeze

  attributes :id, :first_name, :last_name, :email_address, :phone, :avatar_url, :date_of_birth, :full_name


  attribute :expense_summary do |user, params|
    user.expense_summary if params && params[:current_user] && user.id == params[:current_user].id
  end

  has_many :groups, through: :group_memberships

  has_many :friends, serializer: UserSerializer do |user|
    user.all_friends
  end
end
