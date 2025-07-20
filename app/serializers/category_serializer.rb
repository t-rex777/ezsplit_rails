class CategorySerializer
  include JSONAPI::Serializer
  attributes :name, :icon, :color
  belongs_to :created_by, serializer: UserSerializer
end
