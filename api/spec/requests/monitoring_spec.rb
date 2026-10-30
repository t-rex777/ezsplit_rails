require "rails_helper"

RSpec.describe "Monitoring dashboard", type: :request do
  let!(:user) { create(:user) }
  let(:credentials) { ActionController::HttpAuthentication::Basic.encode_credentials("admin", "s3cret-pass") }

  def json
    Oj.load(response.body)
  end

  around do |example|
    previous_stats = Monitoring.stats
    Monitoring.stats = Monitoring::LiveStats.new
    ENV["MONITORING_USERNAME"] = "admin"
    ENV["MONITORING_PASSWORD"] = "s3cret-pass"
    example.run
  ensure
    ENV.delete("MONITORING_USERNAME")
    ENV.delete("MONITORING_PASSWORD")
    Monitoring.stats = previous_stats
  end

  it "does not exist when no credentials are configured" do
    ENV.delete("MONITORING_PASSWORD")

    get monitoring_url, headers: { "Authorization" => credentials }

    expect(response).to have_http_status(:not_found)
  end

  it "asks for a password" do
    get monitoring_url

    expect(response).to have_http_status(:unauthorized)
  end

  it "rejects a wrong password" do
    get monitoring_url, headers: { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "nope") }

    expect(response).to have_http_status(:unauthorized)
  end

  it "shows the page with the right password" do
    get monitoring_url, headers: { "Authorization" => credentials }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("ezsplit monitoring")
  end

  describe "the live data" do
    before do
      sign_in(user)
      get groups_url, as: :json
      allow_any_instance_of(GroupsController).to receive(:index).and_raise(RuntimeError, "boom")
      get groups_url, as: :json
    end

    it "reports traffic, recent requests, and errors" do
      get monitoring_url(format: :json), headers: { "Authorization" => credentials }

      expect(response).to have_http_status(:ok)
      expect(json["totals"]).to include("requests" => 3, "server_errors" => 1, "active_errors" => 1)
      expect(json["series"].size).to eq(60)
      expect(json["series"].last["requests"]).to eq(3)
      expect(json["endpoints"].map { |e| e["endpoint"] }).to include("GET /groups", "POST /session")
      expect(json["recent_requests"].first).to include("method" => "GET", "path" => "/groups", "status" => 500, "user_id" => user.id)
      expect(json["errors"].first).to include("error_class" => "RuntimeError", "message" => "boom", "occurrences" => 1)
    end

    it "does not count its own polling" do
      2.times { get monitoring_url(format: :json), headers: { "Authorization" => credentials } }

      expect(json["totals"]["requests"]).to eq(3)
    end
  end
end
