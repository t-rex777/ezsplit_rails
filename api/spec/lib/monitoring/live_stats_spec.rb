require "rails_helper"

RSpec.describe Monitoring::LiveStats do
  subject(:stats) { described_class.new }

  def record(status: 200, duration_ms: 10.0, route: "/groups", rack_attack: nil)
    stats.record_request(method: "GET", route: route, path: route, status: status, duration_ms: duration_ms,
                         ip: "127.0.0.1", user_id: 1, rack_attack: rack_attack)
  end

  after { Timecop.return }

  it "adds up the current minute" do
    Timecop.freeze(Time.zone.parse("2026-10-30 10:00:10"))
    record(status: 200, duration_ms: 10)
    record(status: 404, duration_ms: 20)
    record(status: 500, duration_ms: 30)
    record(status: 429, duration_ms: 1, route: "(rate limited)", rack_attack: :throttle)

    metrics = stats.current_metrics
    expect(metrics).to include(requests: 4, server_errors: 1, client_errors: 2, throttled: 1, blocked: 0, max_ms: 30)
    expect(metrics[:statuses]).to eq("200" => 1, "404" => 1, "500" => 1, "429" => 1)
    expect(metrics[:endpoints]["GET /groups"]).to eq("count" => 3, "errors" => 1, "total_ms" => 60.0)
  end

  it "computes p95 from the minute's samples" do
    Timecop.freeze(Time.zone.parse("2026-10-30 10:00:10"))
    (1..100).each { |ms| record(duration_ms: ms.to_f) }

    expect(stats.current_metrics[:p95_ms]).to eq(95.0)
  end

  it "saves the finished minute when the next one starts" do
    Timecop.freeze(Time.zone.parse("2026-10-30 10:00:10"))
    2.times { record }

    Timecop.freeze(Time.zone.parse("2026-10-30 10:01:05"))
    expect { record }.to change(RequestMetric, :count).by(1)

    saved = RequestMetric.last
    expect(saved.minute).to eq(Time.zone.parse("2026-10-30 10:00:00"))
    expect(saved.requests).to eq(2)
    expect(saved.endpoints).to eq("GET /groups" => { "count" => 2, "errors" => 0, "total_ms" => 20.0 })
    expect(stats.current_metrics[:requests]).to eq(1)
  end

  it "keeps only the latest 50 requests" do
    60.times { |i| record(route: "/r#{i}") }

    expect(stats.recent_requests.size).to eq(50)
    expect(stats.recent_requests.first[:path]).to eq("/r59")
  end

  it "flushes the unfinished minute" do
    record

    expect { stats.flush }.to change(RequestMetric, :count).by(1)
    expect(stats.current_metrics).to be_nil
  end

  describe ".mask_path" do
    it "hides long tokens in paths" do
      expect(Monitoring.mask_path("/passwords/eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaHBCZz09--abc/edit")).to eq("/passwords/…/edit")
      expect(Monitoring.mask_path("/groups/12")).to eq("/groups/12")
    end
  end
end
