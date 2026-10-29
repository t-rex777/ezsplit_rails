class Activity < ApplicationRecord
  ACTIONS = %w[created updated deleted settled].freeze

  belongs_to :actor, class_name: "User"
  has_many :activity_participants, dependent: :delete_all
  has_many :participants, through: :activity_participants, source: :user

  validates :action, inclusion: { in: ACTIONS }

  # Group entries follow current membership; friend entries stay with the people who were in the expense.
  scope :visible_to, ->(user) {
    where(group_id: user.active_group_memberships.select(:group_id))
      .or(where(group_id: nil, id: ActivityParticipant.where(user_id: user.id).select(:activity_id)))
  }

  # Returns nil without writing when an update changed nothing.
  def self.record!(actor:, action:, group_id:, before:, after:, expense_id: nil, settlement_id: nil)
    return nil if action == "updated" && before == after

    activity = create!(actor: actor, action: action, expense_id: expense_id, settlement_id: settlement_id,
                       group_id: group_id, before_snapshot: before, after_snapshot: after)
    ids = [ actor.id ] + [ before, after ].compact.flat_map { |s| people_in(s) }
    ActivityParticipant.insert_all(ids.uniq.map { |user_id| { activity_id: activity.id, user_id: user_id } })
    activity
  end

  def self.people_in(snapshot)
    [ snapshot["creator_id"], snapshot.dig("payer", "id"), snapshot.dig("payee", "id") ].compact +
      snapshot["shares"].to_a.map { |s| s["user_id"] }
  end
  private_class_method :people_in

  def changed_fields
    return [] unless action == "updated"

    (before_snapshot.keys | after_snapshot.keys).reject { |key| before_snapshot[key] == after_snapshot[key] }
  end

  # Group name from the snapshot, so it survives the expense being deleted.
  def group_summary
    (after_snapshot || before_snapshot)&.dig("group")
  end
end
