class ApplicationController < ActionController::Base
  include Authentication
  include Pagy::Backend

  # as this will be running only in mobile app
  skip_before_action :verify_authenticity_token
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  private

  def current_user
    @current_user ||= Current.user
  end

  # Group members must be me, my friends, or people already in the group.
  def only_friends?(user_ids, group = nil)
    allowed = current_user.all_friends.ids + [ current_user.id ]
    allowed += group.group_memberships.active.pluck(:user_id) if group
    (Array(user_ids).map(&:to_i) - allowed).empty?
  end

  def render_friends_only_error
    render json: { errors: [ "You can only add friends to a group." ] }, status: :unprocessable_entity
  end

  def pagy_metadata(pagy)
      {
        total: pagy.count,
        current_page: pagy.page,
        prev_page: pagy.prev,
        next_page: pagy.next,
        total_pages: pagy.pages
      }
  end
end
