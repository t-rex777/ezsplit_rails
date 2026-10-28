class Friendship < ApplicationRecord
  belongs_to :user
  belongs_to :friend, class_name: "User"

  validates :user_id, uniqueness: { scope: :friend_id }
  validates :friend_id, uniqueness: { scope: :user_id }
  validate :not_self

  private

  def not_self
    errors.add(:friend, "can't be yourself") if user_id == friend_id
  end
end
