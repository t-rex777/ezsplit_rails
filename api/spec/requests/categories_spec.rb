require "rails_helper"

RSpec.describe "Categories", type: :request do
  let!(:user) { create(:user) }
  let!(:user2) { create(:user) }

  before do
    post session_url, params: { email_address: user.email_address, password: user.password }
  end

  describe "GET /categories" do
    let!(:categories) do
      [
        create(:category, name: "Sample Category", user_id: user.id),
        create(:category, name: "Sample Category 2", user_id: user.id),
        create(:category, name: "Sample Category 3", user_id: user2.id)
      ]
    end

    it "returns paginated response" do
      get categories_url

      response_body = Oj.load(response.body)
      expect(response).to be_successful
      expect(response_body["data"].length).to eq(2)
      expect(response_body["data"][0]["attributes"]).to include(
        "name" => "Sample Category"
      )
      expect(response_body["data"][1]["attributes"]).to include(
        "name" => "Sample Category 2"
      )
    end

    it "does not return categories created by other users" do
      get categories_url

      response_body = Oj.load(response.body)
      expect(response).to be_successful
      expect(response_body["data"].length).to eq(2)
      expect(response_body["data"][0]["attributes"]).to include(
        "name" => "Sample Category"
      )
      expect(response_body["data"][1]["attributes"]).to include(
        "name" => "Sample Category 2"
      )
    end
  end

  describe "GET /categories/:id" do
    let!(:category) { create(:category, name: "Sample Category", user_id: user.id) }

    it "returns the category" do
      get category_url(category)

      response_body = Oj.load(response.body)
      expect(response).to be_successful
      expect(response_body["data"]["attributes"]).to include(
        "name" => "Sample Category"
      )
    end
  end

  describe "POST /categories" do
    it "creates a new category" do
      post categories_url, params: { category: { name: "Sample Category" } }, as: :json

      response_body = Oj.load(response.body)
      expect(response).to be_successful
      expect(response_body["data"]["attributes"]).to include(
        "name" => "Sample Category"
      )
    end

    context "with invalid params" do
      it "does not create a new category when name is missing" do
        post categories_url, params: { category: { name: nil } }, as: :json

        response_body = Oj.load(response.body)
        expect(response_body["errors"]).to include("Name can't be blank")
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "PUT /categories/:id" do
    let!(:category) { create(:category, name: "Sample Category", user_id: user.id) }

    it "updates the provided category" do
      put category_url(category), params: { category: { name: "Not Sample Category" } }, as: :json

      response_body = Oj.load(response.body)
      expect(response_body["data"]["attributes"]).to include(
        "name" => "Not Sample Category"
      )
    end
  end

  describe "DELETE /categories/:id" do
    let!(:category) { create(:category, name: "Sample Category", user_id: user.id) }

    it "deletes the provided category" do
      delete category_url(category), as: :json

      response_body = Oj.load(response.body)
      expect(response_body["message"]).to eq("Category was successfully destroyed.")
      expect(Category.exists?(category.id)).to be(false)
    end
  end
end
