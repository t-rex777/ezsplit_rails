require "rails_helper"

RSpec.describe "Rate limits and blocking", type: :request do
  let!(:user) { create(:user, email_address: "me@example.com") }

  def json
    Oj.load(response.body)
  end

  def login(email: user.email_address, password: "wrong", ip: "203.0.113.1")
    post session_url, params: { email_address: email, password: password }, as: :json, env: { "REMOTE_ADDR" => ip }
  end

  around do |example|
    previous_stats = Monitoring.stats
    Monitoring.stats = Monitoring::LiveStats.new
    Rack::Attack.enabled = true
    Rack::Attack.reset!
    example.run
  ensure
    Rack::Attack.enabled = false
    Rack::Attack.reset!
    Monitoring.stats = previous_stats
  end

  describe "logins" do
    it "allows 10 attempts a minute from one IP, then answers 429 with Retry-After" do
      10.times { login(email: "user#{rand(1_000_000)}@example.com") }
      expect(response).to have_http_status(:unauthorized)

      login(email: "another@example.com")

      expect(response).to have_http_status(:too_many_requests)
      expect(response.headers["retry-after"].to_i).to be_between(1, 60)
      expect(json["errors"].first).to start_with("Too many requests. Try again in")
    end

    it "limits attempts on one account even when they come from many IPs" do
      10.times { |i| login(ip: "198.51.100.#{i + 1}") }

      login(email: " ME@example.com ", ip: "198.51.100.200")

      expect(response).to have_http_status(:too_many_requests)
    end

    it "logs the throttle as a security event" do
      11.times { login }

      event = Monitoring.stats.security_events.first
      expect(event).to include(type: "throttle", rule: "logins per ip", ip: "203.0.113.1", path: "/session")
    end
  end

  describe "password resets" do
    it "allows 3 reset emails an hour per address" do
      3.times { |i| post passwords_url, params: { email_address: user.email_address }, as: :json, env: { "REMOTE_ADDR" => "192.0.2.#{i + 1}" } }
      expect(response).to have_http_status(:ok)

      post passwords_url, params: { email_address: user.email_address }, as: :json, env: { "REMOTE_ADDR" => "192.0.2.50" }

      expect(response).to have_http_status(:too_many_requests)
    end
  end

  describe "scanner bots" do
    it "bans an IP from every path after 3 probes for files this app does not have" do
      %w[/wp-login.php /.env /phpmyadmin].each { |path| get path, env: { "REMOTE_ADDR" => "192.0.2.9" } }

      get up_url, env: { "REMOTE_ADDR" => "192.0.2.9" }
      expect(response).to have_http_status(:ok)

      login(ip: "192.0.2.9")

      expect(response).to have_http_status(:forbidden)
      expect(json["errors"]).to eq([ "Access denied." ])
    end

    it "leaves other IPs alone" do
      %w[/wp-login.php /.env /phpmyadmin].each { |path| get path, env: { "REMOTE_ADDR" => "192.0.2.9" } }

      login(ip: "192.0.2.10")

      expect(response).to have_http_status(:unauthorized)
    end
  end

  it "counts refused requests on the dashboard" do
    11.times { login }

    expect(Monitoring.stats.current_metrics).to include(throttled: 1, requests: 11)
    expect(Monitoring.stats.current_metrics[:endpoints]).to include("POST (rate limited)")
  end

  def up_url
    rails_health_check_url
  end
end
