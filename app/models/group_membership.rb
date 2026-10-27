class GroupMembership < ApplicationRecord
  belongs_to :user
  belongs_to :group

  validates :user_id, uniqueness: { scope: :group_id }

  before_create :set_joined_at

  scope :active, -> { where(left_at: nil) }

  private

  def set_joined_at
    self.joined_at ||= Date.current
  end
end
