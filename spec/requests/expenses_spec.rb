require 'rails_helper'

RSpec.describe "Expenses", type: :request do
  let!(:user) { create(:user) }
  let!(:second_user) { create(:user, first_name: "Second", last_name: "User", email_address: "second@example.com") }
  let!(:third_user) { create(:user, first_name: "Third", last_name: "User", email_address: "third@example.com") }

  before do
    Timecop.freeze(Time.local(1990))
    post session_url, params: { email_address: user.email_address, password: user.password }
  end


  after do
    Timecop.return
  end

  let!(:group) { create(:group, created_by: user) }
  let!(:category) { create(:category, created_by: user) }

  describe "GET /expenses" do
    let!(:expenses) { create_list(:expense, 10, payer: user, group: group, category: category) }

    it "returns all the expenses with pagination" do
      get expenses_url

      response_body = Oj.load(response.body)
      expect(response).to have_http_status(200)
      expect(response_body["data"].size).to eq(10)
    end
  end

  describe "POST /expense" do
    let(:expense_params) { { expense: { name: "Test Expense", amount: 90, split_type: "equal", currency: "INR", expense_date: Date.current, settled: false, payer_id: user.id, group_id: group.id, category_id: category.id,
      distribution: [
        { user_id: user.id, amount: 30 },
        { user_id: second_user.id, amount: 30 },
        { user_id: third_user.id, amount: 30 }
      ]
      } } }

    it "creates an expense with valid params" do
      post expenses_url, params: expense_params

      response_body = Oj.load(response.body)
      expect(response).to be_successful
      expect(response_body).to eq({
        data: {
          id: "1",
          type: "expense",
          attributes: {
            name: "Test Expense",
            amount: "90.0",
            split_type: "equal",
            currency: "INR",
            expense_date: Date.current.strftime("%Y-%m-%d"),
            settled: false
          },
          relationships: {
            payer: {
              data: {
                id: user.id.to_s,
                type: "user"
              }
            },
              group: {
                data: {
                  id: group.id.to_s,
                  type: "group"
                }
              },
              category: {
                data: {
                  id: category.id.to_s,
                  type: "category"
                }
            }
          }
        }
      }.with_indifferent_access)
    end

    context "with invalid params" do
      it "does not when currency is invalid" do
        post expenses_url, params: { expense: expense_params[:expense].merge(currency: "INVALID") }

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "does not create when payer user does not exist" do
        post expenses_url, params: { expense: expense_params[:expense].merge(payer_id: "234") }

        response_body = Oj.load(response.body)
        expect(response_body["errors"]).to include("Validation failed: Payer must exist")
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "does not create when group does not exist" do
        post expenses_url, params: { expense: expense_params[:expense].merge(group_id: "12") }

        response_body = Oj.load(response.body)
        expect(response_body["errors"]).to include("Validation failed: Group must exist")
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "does not create when category does not exist" do
        post expenses_url, params: { expense: expense_params[:expense].merge(category_id: "125") }

        response_body = Oj.load(response.body)
        expect(response_body["errors"]).to include("Validation failed: Category must exist")
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "does not create when split type is invalid" do
        post expenses_url, params: { expense: expense_params[:expense].merge(split_type: "invalid") }

        response_body = Oj.load(response.body)
        expect(response_body["errors"]).to include("Split type must be equal, percentage or exact")
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "does not create when currency is invalid" do
        post expenses_url, params: { expense: expense_params[:expense].merge(currency: "invalid") }

        response_body = Oj.load(response.body)
        expect(response_body["errors"]).to include("Validation failed: Currency must be INR or USD")
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "does not create an expense with invalid distribution" do
        invalid_expense_params = expense_params.deep_dup
        invalid_expense_params[:expense][:distribution] = [
          { user_id: user.id, amount: 35 },
          { user_id: second_user.id, amount: 30 },
          { user_id: third_user.id, amount: 30 }
        ]

        post expenses_url, params: invalid_expense_params

        response_body = Oj.load(response.body)
        puts response_body
        expect(response_body["errors"]).to include("Amount must be equal to the sum of the distribution")
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
