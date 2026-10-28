class CategorySerializer
  include JSONAPI::Serializer
  attributes :name, :icon, :color, :created_at
  belongs_to :user
end
