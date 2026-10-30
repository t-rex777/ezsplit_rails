# Rate limits and abuse blocking. Rules run in order: safelist, blocklists, then throttles.
# Hits show up on /monitoring under "Security events".
class Rack::Attack
  # Bots probing for WordPress, PHP, or leaked config files. This app has none of them.
  SCANNER_PATH = %r{\.(php|asp|aspx|jsp|cgi)\b|/wp-(admin|login|content|includes)|/\.(env|git|aws)|/phpmyadmin|/xmlrpc}i

  # Counters live in this process's memory: one SQLite write per request would cost more than it protects.
  # This is enough on a single machine; move to a shared store if the app runs on several.
  cache.store = ActiveSupport::Cache::MemoryStore.new(size: 32.megabytes)

  # Specs run every request from 127.0.0.1, so throttles would trip; spec/requests/rack_attack_spec.rb turns it on.
  self.enabled = !Rails.env.test?

  # Same client IP that Rails logs, resolved from the Fly proxy's X-Forwarded-For header.
  def self.client_ip(request)
    request.env["action_dispatch.remote_ip"]&.to_s.presence || request.ip
  end

  def self.endpoint?(request, method, *paths)
    request.request_method == method && paths.include?(request.path.delete_suffix(".json"))
  end

  # Reads a param from the query string or a form or JSON body.
  def self.param(request, key)
    action_request = ActionDispatch::Request.new(request.env)
    action_request.request_parameters[key] || action_request.query_parameters[key]
  rescue ActionDispatch::Http::Parameters::ParseError, ActionController::BadRequest
    nil
  end

  def self.normalized_email(request)
    param(request, "email_address").to_s.downcase.strip.presence
  end

  safelist("health check") { |request| request.path == "/up" }

  # 3 scanner hits within 10 minutes bans the IP from every path for an hour.
  blocklist("scanner ban") do |request|
    Rack::Attack::Fail2Ban.filter("scanner:#{client_ip(request)}", maxretry: 3, findtime: 10.minutes, bantime: 1.hour) do
      SCANNER_PATH.match?(request.path)
    end
  end

  # A client sending over 600 requests in a minute is flooding, not using the app. Ban it for 10 minutes.
  blocklist("flood ban") do |request|
    Rack::Attack::Allow2Ban.filter("flood:#{client_ip(request)}", maxretry: 600, findtime: 1.minute, bantime: 10.minutes) { true }
  end

  # Overall cap per IP. Generous, since people on one mobile network can share an IP.
  throttle("requests per ip", limit: 300, period: 5.minutes) { |request| client_ip(request) }

  # Password guessing, from one IP or spread across many IPs against one account.
  throttle("logins per ip", limit: 10, period: 1.minute) do |request|
    client_ip(request) if endpoint?(request, "POST", "/session")
  end
  throttle("logins per email", limit: 10, period: 15.minutes) do |request|
    normalized_email(request) if endpoint?(request, "POST", "/session")
  end

  # These send email, so abuse would spam real inboxes and hurt our sender reputation.
  throttle("password resets per ip", limit: 5, period: 15.minutes) do |request|
    client_ip(request) if endpoint?(request, "POST", "/passwords")
  end
  throttle("password resets per email", limit: 3, period: 1.hour) do |request|
    normalized_email(request) if endpoint?(request, "POST", "/passwords")
  end
  throttle("sign-ups per ip", limit: 5, period: 15.minutes) do |request|
    client_ip(request) if endpoint?(request, "POST", "/user_registers")
  end
  throttle("invitations per ip", limit: 30, period: 1.hour) do |request|
    client_ip(request) if endpoint?(request, "POST", "/invitations", "/invitations/qr")
  end

  # Slows password guessing on the dashboard's login prompt. The page itself polls 12 times a minute.
  throttle("monitoring per ip", limit: 30, period: 1.minute) do |request|
    client_ip(request) if request.path.start_with?("/monitoring")
  end

  # Same shape as other API errors: the mobile app shows errors.first to the user.
  self.throttled_responder = lambda do |request|
    match = request.env["rack.attack.match_data"]
    retry_after = match[:period] - (match[:epoch_time] % match[:period])
    body = {
      status: "error",
      errors: [ "Too many requests. Try again in #{retry_after} seconds." ],
      message: "Rate limit exceeded"
    }
    [ 429, { "content-type" => "application/json", "retry-after" => retry_after.to_s }, [ body.to_json ] ]
  end

  self.blocklisted_responder = lambda do |_request|
    body = { status: "error", errors: [ "Access denied." ], message: "Forbidden" }
    [ 403, { "content-type" => "application/json" }, [ body.to_json ] ]
  end
end
