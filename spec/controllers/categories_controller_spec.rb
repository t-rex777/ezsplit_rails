require "rails_helper"

RSpec.describe CategoriesController, type: :controller do
  before do
    # Create and set session for user1
    session = user.sessions.create!(user_agent: "test", ip_address: "127.0.0.1")
    cookies.signed[:session_id] = session.id
  end

  let!(:user) { create(:user) }

  describe "GET #index" do
    let!(:categories) do
      [
        create(:category, name: "Sample Category", created_by_id: user.id),
        create(:category, name: "Sample Category 2", created_by_id: user.id)
      ]
    end

    it "returns paginated response" do
      get :index
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

  describe "GET #show" do
    let!(:category) { create(:category, name: "Sample Category", created_by_id: user.id) }

    it "returns the category" do
      get :show, params: { id: category.id }

      response_body = Oj.load(response.body)
      expect(response).to be_successful
      expect(response_body["data"]["attributes"]).to include(
        "name" => "Sample Category"
      )
    end
  end

  describe "POST #create" do
    it "creates a new category" do
      post :create, params: { category: { name: "Sample Category", created_by_id: user.id } }, format: :json

      response_body = Oj.load(response.body)
      expect(response).to be_successful
      expect(response_body["data"]["attributes"]).to include(
        "name" => "Sample Category"
      )
    end
  end

  describe "PUT #update" do
    let!(:category) { create(:category, name: "Sample Category", created_by_id: user.id) }

    it "updates the provided category" do
      put :update, params: { id: category.id, category: { name: "Not Sample Category" } }, format: :json

      response_body = Oj.load(response.body)
      expect(response_body["data"]["attributes"]).to include(
        "name" => "Not Sample Category"
      )
    end
  end


  describe "DELETE #destroy" do
    let!(:category) { create(:category, name: "Sample Category", created_by_id: user.id) }

    it "deletes the provided category" do
      delete :destroy, params: { id: category.id }, format: :json

      response_body = Oj.load(response.body)
      expect(response_body["message"]).to eq("Category was successfully destroyed.")
      expect(Category.exists?(category.id)).to be(false)
    end
  end
end
