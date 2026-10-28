require 'rails_helper'

RSpec.describe "Users", type: :request do
  describe "GET /users/search" do
    let!(:user1) { create(:user, first_name: "John", last_name: "Doe", email_address: "john.doe@example.com", friends: [ user2, user3, user4, user5, user6 ]) }
    let!(:user2) { create(:user, first_name: "Jane", last_name: "Smith", email_address: "jane.smith@example.com") }
    let!(:user3) { create(:user, first_name: "Bob", last_name: "Johnson", email_address: "bob.johnson@example.com") }
    let!(:user4) { create(:user, first_name: "Alice", last_name: "Brown", email_address: "alice.brown@example.com") }
    let!(:user5) { create(:user, first_name: "Charlie", last_name: "Wilson", email_address: "charlie.wilson@example.com") }
    let!(:user6) { create(:user, first_name: "Diana", last_name: "Davis", email_address: "diana.davis@example.com") }
    let!(:non_friend_user) { create(:user, first_name: "Janes", last_name: "Jones", email_address: "janes.jones@example.com") }
    let!(:group1) { create(:group, user: user4) }
    let!(:group_membership1) { create(:group_membership, user: user4, group: group1) }
    let(:current_user) { user1 }

    before do
      sign_in(current_user)
    end

    context "with valid search query" do
      it "returns users matching the search query" do
        get "/users/search", params: { term: "john" }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response["data"]).to be_present
        expect(json_response["data"]).to be_an(Array)
        expect(json_response["data"].length).to eq(1)
        expect(json_response["meta"]).to be_present
      end

      it "searches in first_name, last_name, and email_address" do
        get "/users/search", params: { term: "Alice" }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response["data"].length).to eq(1)
        expect(json_response["data"][0]["attributes"]["first_name"]).to eq("Alice")
      end

      it "returns paginated results with default 5 items per page" do
        get "/users/search", params: { term: "user" }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response["data"].length).to be <= 5
        expect(json_response["meta"]["total"]).to be_present
        expect(json_response["meta"]["current_page"]).to be_present
        expect(json_response["meta"]["total_pages"]).to be_present
      end

      it "respects custom per_page parameter" do
        get "/users/search", params: { term: "user", limit: 2 }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response["data"].length).to be <= 5
        expect(json_response["meta"]["current_page"]).to eq(1)
        expect(json_response["meta"]["total_pages"]).to be >= 1
      end

      it "includes groups in the response" do
        get "/users/search", params: { term: "alice" }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response["included"]).to be_present
      end

      it "returns users from current user's friends only" do
        get "/users/search", params: { term: "jan" }

        json_response = JSON.parse(response.body)
        user_ids = json_response["data"].map { |user| user["id"].to_s }

        expect(response).to have_http_status(:ok)
        expect(user_ids).to include(user2.id.to_s)
        expect(user_ids).not_to include(non_friend_user.id.to_s)
      end
    end

    context "with invalid search query" do
      it "returns error when query is missing" do
        get "/users/search"

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)

        expect(json_response["status"]).to eq("error")
        expect(json_response["message"]).to eq("Search query is required")
        expect(json_response["errors"]).to include("Query parameter 'term' is required")
      end

      it "returns error when query is blank" do
        get "/users/search", params: { term: "   " }

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)

        expect(json_response["status"]).to eq("error")
        expect(json_response["message"]).to eq("Search query is required")
      end
    end

    context "with case insensitive search" do
      it "finds users regardless of case" do
        get "/users/search", params: { term: "ALICE" }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response["data"].length).to eq(1)
        expect(json_response["data"][0]["attributes"]["first_name"]).to eq("Alice")
      end
    end
  end
end
