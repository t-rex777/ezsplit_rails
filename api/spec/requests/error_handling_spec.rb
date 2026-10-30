require "rails_helper"

RSpec.describe "Error handling", type: :request do
  let!(:user) { create(:user) }

  def json
    Oj.load(response.body)
  end

  before { sign_in(user) }

  describe "an unexpected error" do
    before { allow_any_instance_of(GroupsController).to receive(:index).and_raise(RuntimeError, "boom") }

    it "returns a JSON 500 in the API's error shape" do
      get groups_url, as: :json

      expect(response).to have_http_status(:internal_server_error)
      expect(json["errors"]).to eq([ "Something went wrong on our side. Please try again." ])
      expect(json["request_id"]).to be_present
      expect(response.body).not_to include("boom")
    end

    it "records the error once, then counts repeats" do
      expect { get groups_url, as: :json }.to change(AppError, :count).by(1)
      expect { get groups_url, as: :json }.not_to change(AppError, :count)

      error = AppError.last
      expect(error.error_class).to eq("RuntimeError")
      expect(error.message).to eq("boom")
      expect(error.occurrences).to eq(2)
      expect(error.handled).to be(false)
      expect(error.context).to include("controller" => "groups", "action" => "index", "method" => "GET",
                                       "path" => "/groups", "user_id" => user.id)
    end
  end

  it "returns a JSON 404 for a missing record" do
    allow_any_instance_of(GroupsController).to receive(:index).and_raise(ActiveRecord::RecordNotFound)

    get groups_url, as: :json

    expect(response).to have_http_status(:not_found)
    expect(json["errors"]).to eq([ "Not found" ])
  end

  it "does not record expected errors like a missing record" do
    allow_any_instance_of(GroupsController).to receive(:index).and_raise(ActiveRecord::RecordNotFound)

    expect { get groups_url, as: :json }.not_to change(AppError, :count)
  end

  it "returns a JSON 400 for a missing parameter" do
    post groups_url, params: {}, as: :json

    expect(response).to have_http_status(:bad_request)
    expect(json["errors"]).to eq([ "Missing parameter: group" ])
  end
end
