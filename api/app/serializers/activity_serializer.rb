class ActivitySerializer
  include JSONAPI::Serializer
  attributes :action, :expense_id, :settlement_id, :created_at, :changed_fields
  attribute(:actor) { |activity| { id: activity.actor_id, name: activity.actor.full_name } }
  attribute(:group) { |activity| activity.group_summary }
  attribute(:before) { |activity| activity.before_snapshot }
  attribute(:after) { |activity| activity.after_snapshot }
end
