class ApplicationController < ActionController::Base
  include Authentication
  include Pagy::Backend

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
