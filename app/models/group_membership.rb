class GroupMembership < ApplicationRecord
  belongs_to :user
  belongs_to :group

  before_create :set_joined_at

  private

  def set_joined_at
    self.joined_at ||= Date.current
  end
end
