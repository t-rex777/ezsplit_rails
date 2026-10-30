# The numbers behind /monitoring: the last hour of saved minutes, plus this
# process's minute in progress, plus recent errors and rate-limit hits.
class MonitoringReport
  WINDOW_MINUTES = 60
  COUNTERS = %i[requests server_errors client_errors throttled blocked].freeze

  def initialize(stats: Monitoring.stats, now: Time.current)
    @stats = stats
    @now = now
    @first_minute = (now - (WINDOW_MINUTES - 1).minutes).beginning_of_minute
  end

  def as_json(*)
    minutes = merged_minutes
    {
      generated_at: @now.iso8601,
      window_minutes: WINDOW_MINUTES,
      totals: totals(minutes),
      series: series(minutes),
      endpoints: endpoints(minutes),
      statuses: statuses(minutes),
      recent_requests: @stats.recent_requests,
      security_events: @stats.security_events,
      errors: errors
    }
  end

  private

  # Rows from every process, keyed by minute, with counts summed.
  def merged_minutes
    rows = RequestMetric.since(@first_minute).map { |metric| metric.attributes.symbolize_keys }
    live = @stats.current_metrics
    rows << live if live
    rows.select { |row| row[:minute] >= @first_minute }.group_by { |row| row[:minute].to_i }.transform_values do |group|
      group.reduce { |merged, row| merge_rows(merged, row) }
    end
  end

  def merge_rows(a, b)
    merged = COUNTERS.to_h { |key| [ key, a[key] + b[key] ] }
    merged.merge(
      minute: a[:minute],
      total_ms: a[:total_ms] + b[:total_ms],
      max_ms: [ a[:max_ms], b[:max_ms] ].max,
      # Exact p95 across processes would need every sample; the higher one is the honest upper bound.
      p95_ms: [ a[:p95_ms], b[:p95_ms] ].max,
      statuses: a[:statuses].merge(b[:statuses]) { |_status, x, y| x + y },
      endpoints: a[:endpoints].merge(b[:endpoints]) { |_endpoint, x, y| x.merge(y) { |_key, i, j| i + j } }
    )
  end

  def totals(minutes)
    rows = minutes.values
    sums = COUNTERS.to_h { |key| [ key, rows.sum { |row| row[key] } ] }
    total_ms = rows.sum { |row| row[:total_ms] }
    latest = minutes[@now.beginning_of_minute.to_i]

    sums.merge(
      error_rate: sums[:requests].zero? ? 0.0 : (100.0 * sums[:server_errors] / sums[:requests]).round(2),
      avg_ms: sums[:requests].zero? ? 0.0 : (total_ms / sums[:requests]).round(1),
      worst_p95_ms: rows.map { |row| row[:p95_ms] }.max || 0.0,
      requests_this_minute: latest ? latest[:requests] : 0,
      active_errors: AppError.where(last_seen_at: @first_minute..).count
    )
  end

  def series(minutes)
    Array.new(WINDOW_MINUTES) do |i|
      minute = @first_minute + i.minutes
      row = minutes[minute.to_i]
      {
        minute: minute.iso8601,
        requests: row ? row[:requests] : 0,
        server_errors: row ? row[:server_errors] : 0,
        rate_limited: row ? row[:throttled] + row[:blocked] : 0,
        p95_ms: row ? row[:p95_ms] : 0.0
      }
    end
  end

  def endpoints(minutes)
    combined = minutes.values.map { |row| row[:endpoints] }
      .reduce({}) { |all, endpoints| all.merge(endpoints) { |_endpoint, x, y| x.merge(y) { |_key, i, j| i + j } } }

    combined.map { |endpoint, stats|
      { endpoint: endpoint, count: stats["count"], errors: stats["errors"], avg_ms: (stats["total_ms"] / stats["count"]).round(1) }
    }.sort_by { |row| -row[:count] }.first(15)
  end

  def statuses(minutes)
    minutes.values.map { |row| row[:statuses] }
      .reduce({}) { |all, statuses| all.merge(statuses) { |_status, x, y| x + y } }
      .sort.to_h
  end

  def errors
    AppError.recent.limit(25).map do |error|
      {
        id: error.id,
        error_class: error.error_class,
        message: error.message,
        severity: error.severity,
        handled: error.handled,
        source: error.source,
        context: error.context,
        occurrences: error.occurrences,
        first_seen_at: error.first_seen_at.iso8601,
        last_seen_at: error.last_seen_at.iso8601,
        backtrace: error.backtrace.to_s.lines.first(15).join
      }
    end
  end
end
