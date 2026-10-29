class ActivitiesController < ApplicationController
  # GET /activities
  # group_id=none returns expenses outside any group.
  def index
    activities = Activity.visible_to(current_user).includes(:actor).order(created_at: :desc, id: :desc)
    activities = activities.where(group_id: params[:group_id] == "none" ? nil : params[:group_id]) if params[:group_id].present?
    pagy_obj, activities = pagy(activities)
    render json: ActivitySerializer.new(activities, meta: pagy_metadata(pagy_obj)).serializable_hash.to_json
  end
end
