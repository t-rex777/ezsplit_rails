require "rails_helper"

RSpec.describe "Expenses", type: :request do
  let!(:user) { create(:user) }
  let!(:second_user) { create(:user, first_name: "Second", last_name: "User", email_address: "second@example.com") }
  let!(:third_user) { create(:user, first_name: "Third", last_name: "User", email_address: "third@example.com") }
  let!(:group) { create(:group, user: user) }
  let!(:category) { create(:category, user: user) }

  before do
    Timecop.freeze
    post session_url, params: { email_address: user.email_address, password: user.password }
  end

  after do
    Timecop.return
  end

  describe "GET /expenses" do
    it "returns all the expenses" do
     create_list(:expense, 10, payer: user, group: group, category: category, user: user)
      get expenses_url

      response_body = Oj.load(response.body)
      expect(response).to be_successful
      expect(response_body["data"].length).to eq(10)
    end

    it "does not return expenses for other users" do
      create_list(:expense, 10, payer: second_user, group: group, category: category, user: second_user)
      get expenses_url

      response_body = Oj.load(response.body)
      expect(response).to be_successful
      expect(response_body["data"].length).to eq(0)
    end
  end

  describe "POST /expenses" do
      let(:expense_params) { {
        expense: {
          name: "Test Expense",
          amount: 90,
          split_type: "equal",
          currency: "INR",
          expense_date: Date.current,
          settled: false,
          payer_id: user.id,
          group_id: group.id,
          category_id: category.id,
          distribution: [
            { user_id: user.id, amount: 30 },
            { user_id: second_user.id, amount: 30 },
            { user_id: third_user.id, amount: 30 }
          ]
        }
      } }
    context "with valid parameters" do
      it "creates a new expense with equal split" do
        post expenses_url, params: expense_params

        response_body = Oj.load(response.body)
        expect(response).to be_successful
        expect(response_body).to eq(
          {
            "data": {
              "attributes": {
                "amount": "90.0",
                "created_at": Time.now.utc.iso8601(3),
                "currency": "INR",
                "expense_date": "2025-08-30",
                "name": "Test Expense",
                "settled": false,
                "split_type": "equal",
                "updated_at": Time.now.utc.iso8601(3)
              },
              "id": "1",
              "relationships": {
                "category": {
                  "data": {
                    "id": "1",
                    "type": "category"
                  }
                },
                "expenses_users": {
                  "data": [
                    { "id": "1", "type": "expenses_user" },
                    { "id": "2", "type": "expenses_user" },
                    { "id": "3", "type": "expenses_user" }
                  ]
                },
                "group": {
                  "data": {
                    "id": "1",
                    "type": "group"
                  }
                },
                "payer": {
                  "data": {
                    "id": "1",
                    "type": "user"
                  }
                }
              },
              "type": "expense"
            }
          }
          .with_indifferent_access)
        expect(ExpensesUser.count).to be(3)
      end
    end

    context "with invalid parameters" do
      it "returns an error when split_type is invalid" do
        expense_params[:expense][:split_type] = "invalid"

        post expenses_url, params: expense_params

        response_body = Oj.load(response.body)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response_body).to eq(
          { "errors": [ "Split type must be equal, percentage or exact" ] }.with_indifferent_access
        )
      end

      it "returns an error when currency is invalid" do
        expense_params[:expense][:currency] = "invalid"

        post expenses_url, params: expense_params

        response_body = Oj.load(response.body)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response_body).to eq(
          { "errors": [ "Validation failed: Currency must be INR or USD" ] }.with_indifferent_access
        )
      end
    end
  end

  describe "PUT /expenses/:id" do
    context "with valid parameters" do
      let(:expense_params) { { expense: { name: "Test Expense", amount: 90, split_type: "equal", currency: "INR", expense_date: Date.current, settled: false, payer_id: user.id, group_id: group.id, category_id: category.id,
        distribution: [
          { user_id: user.id, amount: 30 },
          { user_id: second_user.id, amount: 30 },
          { user_id: third_user.id, amount: 30 }
        ]
      } } }

      let(:expense) { create(:expense, payer: user, group: group, category: category, user: user) }

      it "updates an expense" do
        put expense_url(expense), params: expense_params

        response_body = Oj.load(response.body)
        expect(response).to be_successful
        expect(response_body).to eq(
          {
            "data": {
              "attributes": {
                "amount": "90.0",
                "created_at": Time.now.utc.iso8601(3),
                "currency": "INR",
                "expense_date": "2025-08-30",
                "name": "Test Expense",
                "settled": false,
                "split_type": "equal",
                "updated_at": Time.now.utc.iso8601(3)
              },
              "id": "1",
              "relationships": {
                "category": { "data": { "id": "1", "type": "category" } },
                "expenses_users": {
                  "data": [
                    { "id": "1", "type": "expenses_user" },
                    { "id": "2", "type": "expenses_user" },
                    { "id": "3", "type": "expenses_user" }
                  ]
                },
                "group": { "data": { "id": "1", "type": "group" } },
                "payer": { "data": { "id": "1", "type": "user" } }
              },
              "type": "expense"
            }
          }
          .with_indifferent_access)
      end

      it "does not update expense when wrong id is provided which does not exist" do
          put expense_url({ id: "999" }), params: expense_params

          expect(response).to have_http_status(:not_found)
      end

      it "does not update expense when trying to update another user's expense" do
        expense_2 = create(:expense, payer: second_user, group: group, category: category, user: second_user)

          put expense_url(expense_2), params: expense_params
          expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "DELETE /expenses/:id" do
    let!(:expense) { create(:expense, payer: user, group: group, category: category, user: user) }
    let!(:another_expense) { create(:expense, payer: second_user, group: group, category: category, user: second_user) }

    it "deletes the expense when id is provided" do
      delete expense_url(expense), as: :json

      response_body = Oj.load(response.body)
      expect(response).to be_successful
      expect(response_body).to eq({ "message" => "Expense was successfully deleted" })
      expect(Expense.exists?(expense.id)).to be false
    end

    it "does not delete expense when trying to delete another user's expense" do
      delete expense_url(another_expense), as: :json

      response_body = Oj.load(response.body)
      expect(response).to have_http_status(:not_found)
    end
  end
end
