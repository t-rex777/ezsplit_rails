# One row per distinct error. Repeats bump `occurrences` instead of adding rows.
class AppError < ApplicationRecord
  BACKTRACE_LINES = 30
  MESSAGE_LIMIT = 2_000

  scope :recent, -> { order(last_seen_at: :desc) }

  def self.record(error, severity:, handled:, source:, context: {})
    now = Time.current
    backtrace = Array(error.backtrace).first(BACKTRACE_LINES)
    context = sanitize(context)

    upsert(
      {
        fingerprint: fingerprint_for(error, backtrace, context),
        error_class: error.class.name,
        message: error.message.to_s.truncate(MESSAGE_LIMIT),
        backtrace: backtrace.join("\n"),
        severity: severity.to_s,
        handled: handled,
        source: source,
        context: context,
        occurrences: 1,
        first_seen_at: now,
        last_seen_at: now,
        created_at: now,
        updated_at: now
      },
      unique_by: :fingerprint,
      on_duplicate: Arel.sql(<<~SQL.squish)
        occurrences = occurrences + 1,
        message = excluded.message,
        backtrace = excluded.backtrace,
        context = excluded.context,
        last_seen_at = excluded.last_seen_at,
        updated_at = excluded.updated_at
      SQL
    )
  rescue StandardError => e
    # Never let error logging break the request, and never report from here (it would loop).
    Rails.logger.error("[AppError] could not record #{error.class}: #{e.class}: #{e.message}")
  end

  # The message is left out on purpose: it often holds ids, so the same bug would split into many rows.
  def self.fingerprint_for(error, backtrace, context)
    app_root = Rails.root.join("app").to_s
    app_line = backtrace.find { |line| line.start_with?(app_root) } || backtrace.first
    Digest::SHA256.hexdigest([ error.class.name, app_line, context["controller"], context["action"] ].join("|"))
  end

  # Context can hold whole objects (a job, a request); keep only small plain values.
  def self.sanitize(context)
    context.to_h.each_with_object({}) do |(key, value), clean|
      clean[key.to_s] =
        case value
        when String then value.truncate(500)
        when Numeric, true, false, nil then value
        when Symbol then value.to_s
        else value.class.name
        end
    end
  end
end
