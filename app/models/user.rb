class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :group_memberships, dependent: :destroy
  has_many :groups, through: :group_memberships

  normalizes :email_address, with: ->(e) { e.strip.downcase }
end
