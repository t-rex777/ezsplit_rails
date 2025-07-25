class Category < ApplicationRecord
  validates :name, :created_by_id, presence: true
  belongs_to :created_by, class_name: "User", foreign_key: "created_by_id"
end
