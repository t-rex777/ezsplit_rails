class ApplicationController < ActionController::Base
  include Authentication
  include Pagy::Backend

  # as this will be running only in mobile app
  skip_before_action :verify_authenticity_token
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  private

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
