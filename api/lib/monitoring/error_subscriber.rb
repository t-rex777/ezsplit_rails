module Monitoring
  # Receives everything sent to Rails.error (requests, jobs, Rails.error.handle blocks)
  # and saves it so the dashboard can show it.
  class ErrorSubscriber
    def report(error, handled:, severity:, context:, source: nil)
      AppError.record(error, severity: severity, handled: handled, source: source, context: context)
    end
  end
end
