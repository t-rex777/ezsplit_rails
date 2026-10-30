# Turns uncaught exceptions into the API's usual error shape, and sends unexpected ones
# to Rails.error so they appear on /monitoring.
module ErrorHandling
  extend ActiveSupport::Concern

  included do
    # Later rescue_from calls win, so the catch-all comes first.
    rescue_from StandardError, with: :render_internal_error
    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
    rescue_from ActionController::ParameterMissing, ActionDispatch::Http::Parameters::ParseError, with: :render_bad_request
  end

  private

  def render_not_found(_error)
    render_error_response(:not_found, "Not found")
  end

  def render_bad_request(error)
    message = error.is_a?(ActionController::ParameterMissing) ? "Missing parameter: #{error.param}" : "The request body could not be read."
    render_error_response(:bad_request, message)
  end

  def render_internal_error(error)
    Rails.error.report(error, handled: false, source: "application.action_controller", context: error_context)
    # Keep the full error page while developing; the report above still reaches /monitoring.
    raise error if Rails.env.development?

    render_error_response(:internal_server_error, "Something went wrong on our side. Please try again.")
  end

  def error_context
    {
      controller: controller_name,
      action: action_name,
      method: request.request_method,
      path: request.route_uri_pattern&.delete_suffix("(.:format)"),
      request_id: request.request_id,
      user_id: Current.session&.user_id
    }
  end

  def render_error_response(status, message)
    return if performed?

    if request.format.html?
      render file: Rails.public_path.join("#{Rack::Utils.status_code(status)}.html"), status: status, layout: false
    else
      render json: { status: "error", errors: [ message ], message: message, request_id: request.request_id }, status: status
    end
  end
end
