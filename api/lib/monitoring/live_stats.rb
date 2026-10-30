module Monitoring
  class << self
    attr_accessor :stats
  end

  # Long path segments are usually tokens (password reset links); keep them off the dashboard.
  def self.mask_path(path)
    path.to_s.gsub(%r{/[^/]{24,}}, "/…").truncate(120)
  end

  # This process's live traffic: totals for the current minute, the latest requests,
  # and recent rate-limit hits. When a minute ends its totals are saved as a RequestMetric.
  class LiveStats
    RECENT_LIMIT = 50
    PRUNE_EVERY = 1.hour

    def initialize
      @mutex = Mutex.new
      @bucket = nil
      @recent_requests = []
      @security_events = []
      @pruned_at = nil
    end

    def record_request(method:, route:, path:, status:, duration_ms:, ip:, user_id:, rack_attack: nil)
      now = Time.current
      finished = nil

      @mutex.synchronize do
        minute = now.beginning_of_minute
        if @bucket && @bucket.minute != minute
          finished = @bucket
          @bucket = nil
        end
        @bucket ||= Bucket.new(minute)
        @bucket.add(endpoint: "#{method} #{route}", status: status, duration_ms: duration_ms, rack_attack: rack_attack)

        push(@recent_requests, at: now.iso8601, method: method, path: path, status: status,
                               duration_ms: duration_ms, ip: ip, user_id: user_id)
      end

      persist(finished) if finished
    end

    def record_security_event(type:, rule:, ip:, path:)
      @mutex.synchronize do
        push(@security_events, at: Time.current.iso8601, type: type, rule: rule, ip: ip, path: path)
      end
    end

    def current_metrics
      @mutex.synchronize { @bucket&.to_attributes }
    end

    def recent_requests
      @mutex.synchronize { @recent_requests.dup }
    end

    def security_events
      @mutex.synchronize { @security_events.dup }
    end

    # Saves the unfinished minute, so a restart does not drop it.
    def flush
      bucket = @mutex.synchronize { @bucket.tap { @bucket = nil } }
      persist(bucket) if bucket
    end

    private

    def push(list, entry)
      list.unshift(entry)
      list.pop if list.size > RECENT_LIMIT
    end

    def persist(bucket)
      RequestMetric.create!(bucket.to_attributes)
      prune_old_metrics
    rescue StandardError => e
      Rails.logger.error("[Monitoring] could not save request metrics: #{e.class}: #{e.message}")
    end

    def prune_old_metrics
      return if @pruned_at && @pruned_at > PRUNE_EVERY.ago

      @pruned_at = Time.current
      RequestMetric.prune
    end

    class Bucket
      # Enough samples for a stable p95 without letting a flood grow memory.
      SAMPLE_LIMIT = 5_000

      attr_reader :minute

      def initialize(minute)
        @minute = minute
        @requests = @server_errors = @client_errors = @throttled = @blocked = 0
        @total_ms = @max_ms = 0.0
        @durations = []
        @statuses = Hash.new(0)
        @endpoints = Hash.new { |hash, key| hash[key] = { "count" => 0, "errors" => 0, "total_ms" => 0.0 } }
      end

      def add(endpoint:, status:, duration_ms:, rack_attack:)
        @requests += 1
        @server_errors += 1 if status >= 500
        @client_errors += 1 if status.between?(400, 499)
        # 429s also come from controller-level `rate_limit` (SessionsController), not only Rack::Attack.
        @throttled += 1 if rack_attack == :throttle || status == 429
        @blocked += 1 if rack_attack == :blocklist
        @total_ms += duration_ms
        @max_ms = duration_ms if duration_ms > @max_ms
        @durations << duration_ms if @durations.size < SAMPLE_LIMIT
        @statuses[status.to_s] += 1

        stats = @endpoints[endpoint]
        stats["count"] += 1
        stats["errors"] += 1 if status >= 500
        stats["total_ms"] += duration_ms
      end

      def to_attributes
        {
          minute: @minute,
          requests: @requests,
          server_errors: @server_errors,
          client_errors: @client_errors,
          throttled: @throttled,
          blocked: @blocked,
          total_ms: @total_ms.round(1),
          max_ms: @max_ms,
          p95_ms: p95,
          statuses: @statuses.to_h { |status, count| [ status, count ] },
          endpoints: @endpoints.to_h { |endpoint, stats| [ endpoint, stats.merge("total_ms" => stats["total_ms"].round(1)) ] }
        }
      end

      private

      def p95
        return 0.0 if @durations.empty?

        sorted = @durations.sort
        sorted[((sorted.size - 1) * 0.95).round]
      end
    end
  end
end
