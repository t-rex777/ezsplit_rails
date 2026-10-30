# Traffic totals for one minute, written by Monitoring::LiveStats when the minute ends.
# Each app process writes its own row, so read by summing rows that share a minute.
class RequestMetric < ApplicationRecord
  RETENTION = 7.days

  scope :since, ->(time) { where(minute: time..) }

  def self.prune
    where(minute: ...RETENTION.ago).delete_all
  end
end
