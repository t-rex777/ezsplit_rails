class Group < ApplicationRecord
  belongs_to :user
  has_many :group_memberships, dependent: :destroy
  has_many :users, through: :group_memberships

  validates :name, presence: true
end
