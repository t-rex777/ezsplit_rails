class UserSerializer
  include JSONAPI::Serializer

  # What other users may see. Phone and date of birth stay private.
  PUBLIC_FIELDS = %i[id first_name last_name full_name email_address avatar_url groups].freeze

  attributes :id, :first_name, :last_name, :email_address, :avatar_url, :full_name

  # Only the signed-in user sees their own phone and date of birth.
  self_only = ->(user, params) { user.id == (params&.dig(:current_user) || Current.user)&.id }
  attributes :phone, :date_of_birth, if: self_only

  attribute :expense_summary do |user, params|
    user.expense_summary if params && params[:current_user] && user.id == params[:current_user].id
  end

  has_many :groups, through: :group_memberships

  has_many :friends, serializer: UserSerializer do |user|
    user.all_friends
  end
end
