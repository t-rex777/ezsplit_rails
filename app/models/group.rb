class Group < ApplicationRecord
  belongs_to :created_by, class_name: "User", foreign_key: "created_by_id"
  has_many :group_memberships, dependent: :destroy
  has_many :users, through: :group_memberships
end
