# Live traffic and error dashboard at /monitoring. The page polls /monitoring.json.
# Set MONITORING_USERNAME and MONITORING_PASSWORD to turn it on; without both, it answers 404.
class MonitoringController < ActionController::Base
  before_action :require_monitoring_credentials

  def show
    respond_to do |format|
      format.html { render layout: false }
      format.json { render json: MonitoringReport.new }
    end
  end

  private

  def require_monitoring_credentials
    username = ENV["MONITORING_USERNAME"]
    password = ENV["MONITORING_PASSWORD"]
    return head(:not_found) if username.blank? || password.blank?

    authenticate_or_request_with_http_basic("ezsplit monitoring") do |given_username, given_password|
      # `&` rather than `&&`, so a wrong username takes as long as a wrong password.
      ActiveSupport::SecurityUtils.secure_compare(given_username, username) &
        ActiveSupport::SecurityUtils.secure_compare(given_password, password)
    end
  end
end
