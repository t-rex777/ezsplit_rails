require 'rails_helper'

RSpec.describe "Users", type: :request do
  describe "GET /users/search" do
    let!(:user1) { create(:user, first_name: "John", last_name: "Doe", email_address: "john.doe@example.com") }
    let!(:user2) { create(:user, first_name: "Jane", last_name: "Smith", email_address: "jane.smith@example.com") }
    let!(:user3) { create(:user, first_name: "Bob", last_name: "Johnson", email_address: "bob.johnson@example.com") }
    let!(:user4) { create(:user, first_name: "Alice", last_name: "Brown", email_address: "alice.brown@example.com") }
    let!(:user5) { create(:user, first_name: "Charlie", last_name: "Wilson", email_address: "charlie.wilson@example.com") }
    let!(:user6) { create(:user, first_name: "Diana", last_name: "Davis", email_address: "diana.davis@example.com") }
    let(:current_user) { user1 }

    before do
      sign_in(current_user)
    end

    context "with valid search query" do
      it "returns users matching the search query" do
        get "/users/search", params: { q: "john" }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response["status"]).to eq("success")
        expect(json_response["data"]["users"]["data"]).to be_present
        expect(json_response["data"]["pagination"]).to be_present
      end

      it "searches in first_name, last_name, and email_address" do
        get "/users/search", params: { q: "doe" }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response["data"]["users"]["data"].length).to eq(1)
        expect(json_response["data"]["users"]["data"].first["attributes"]["first_name"]).to eq("John")
      end

      it "returns paginated results with default 5 items per page" do
        get "/users/search", params: { q: "a" }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response["data"]["users"]["data"].length).to be <= 5
        expect(json_response["data"]["pagination"]["count"]).to be_present
        expect(json_response["data"]["pagination"]["page"]).to be_present
        expect(json_response["data"]["pagination"]["items"]).to eq(5)
      end

      it "respects custom per_page parameter" do
        get "/users/search", params: { q: "a", per_page: 3 }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response["data"]["users"]["data"].length).to be <= 3
        expect(json_response["data"]["pagination"]["items"]).to eq(3)
      end

      it "includes groups in the response" do
        get "/users/search", params: { q: "john" }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response["data"]["users"]["included"]).to be_present
      end
    end

    context "with invalid search query" do
      it "returns error when query is missing" do
        get "/users/search"

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)

        expect(json_response["status"]).to eq("error")
        expect(json_response["message"]).to eq("Search query is required")
        expect(json_response["errors"]).to include("Query parameter 'q' is required")
      end

      it "returns error when query is blank" do
        get "/users/search", params: { q: "   " }

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)

        expect(json_response["status"]).to eq("error")
        expect(json_response["message"]).to eq("Search query is required")
      end
    end

    context "with case insensitive search" do
      it "finds users regardless of case" do
        get "/users/search", params: { q: "JOHN" }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response["data"]["users"]["data"].length).to eq(1)
        expect(json_response["data"]["users"]["data"].first["attributes"]["first_name"]).to eq("John")
      end
    end
  end
end
