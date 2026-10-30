module Monitoring
  # Rack middleware that times every request and hands the result to Monitoring.stats.
  # It sits outside Rack::Attack, so rate-limited and blocked requests are counted too.
  class RequestTracker
    SKIP_PREFIXES = %w[/up /monitoring /assets].freeze

    def initialize(app)
      @app = app
    end

    def call(env)
      return @app.call(env) if skip?(env["PATH_INFO"].to_s)

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      status = 500
      status, headers, body = @app.call(env)
      [ status, headers, body ]
    ensure
      track(env, status.to_i, started) if started
    end

    private

    def skip?(path)
      SKIP_PREFIXES.any? { |prefix| path == prefix || path.start_with?("#{prefix}/", "#{prefix}.") }
    end

    def track(env, status, started)
      request = ActionDispatch::Request.new(env)
      rack_attack = env["rack.attack.match_type"]

      Monitoring.stats&.record_request(
        method: request.request_method,
        route: route_for(request, rack_attack),
        path: request.route_uri_pattern&.delete_suffix("(.:format)") || Monitoring.mask_path(request.path),
        status: status,
        duration_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round(1),
        ip: request.remote_ip,
        # Current is still set here: Rails clears it only when the response body is closed.
        user_id: Current.session&.user_id,
        rack_attack: rack_attack
      )
    rescue StandardError => e
      Rails.logger.error("[Monitoring] could not track request: #{e.class}: #{e.message}")
    end

    def route_for(request, rack_attack)
      case rack_attack
      when :throttle then "(rate limited)"
      when :blocklist then "(blocked)"
      else request.route_uri_pattern&.delete_suffix("(.:format)") || "(no route)"
      end
    end
  end
end
