class CategorySerializer
  include JSONAPI::Serializer
  attributes :name, :icon, :color
end
