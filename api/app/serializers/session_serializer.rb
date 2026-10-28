class SessionSerializer
  include JSONAPI::Serializer

  attributes :id, :user_id, :user_agent, :ip_address, :created_at, :last_active_at

  belongs_to :user

  attribute :active do |session|
    session.active?
  end
end
