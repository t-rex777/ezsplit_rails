require Rails.root.join("lib/monitoring/live_stats")
require Rails.root.join("lib/monitoring/request_tracker")
require Rails.root.join("lib/monitoring/error_subscriber")

Monitoring.stats = Monitoring::LiveStats.new

# After RequestId so each request has its id, and before Rack::Attack (added last by its railtie).
Rails.application.config.middleware.insert_after ActionDispatch::RequestId, Monitoring::RequestTracker

Rails.error.subscribe(Monitoring::ErrorSubscriber.new)

ActiveSupport::Notifications.subscribe(/\A(throttle|blocklist)\.rack_attack\z/) do |name, _start, _finish, _id, payload|
  request = payload[:request]
  Monitoring.stats.record_security_event(
    type: name.delete_suffix(".rack_attack"),
    rule: request.env["rack.attack.matched"],
    ip: Rack::Attack.client_ip(request),
    path: Monitoring.mask_path(request.path)
  )
end

at_exit { Monitoring.stats.flush } unless Rails.env.test?
