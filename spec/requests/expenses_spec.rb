require "rails_helper"

RSpec.describe "Expenses", type: :request do
  let!(:user) { create(:user) }
  let!(:second_user) { create(:user, first_name: "Second", last_name: "User", email_address: "second@example.com") }
  let!(:third_user) { create(:user, first_name: "Third", last_name: "User", email_address: "third@example.com") }
  let!(:group) { create(:group, created_by: user) }
  let!(:category) { create(:category, created_by: user) }

  before do
    post session_url, params: { email_address: user.email_address, password: user.password }
  end

  describe "GET /expenses" do
    let!(:expenses) { create_list(:expense, 10, payer: user, group: group, category: category) }

    it "returns all the expenses" do
      get expenses_url

      response_body = Oj.load(response.body)
      expect(response).to be_successful
      expect(response_body["data"].length).to eq(10)
    end
  end

  describe "POST /expenses" do
    context "with valid parameters" do
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

      it "creates a new expense with equal split" do
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
              },
              expenses_users: {
                data: [
                  {
                    id: "1",
                    type: "expenses_user"
                  },
                  {
                    id: "2",
                    type: "expenses_user"
                  },
                  {
                    id: "3",
                    type: "expenses_user"
                  }
                ]
              }
            }
          }
        }.with_indifferent_access)
        expect(ExpensesUser.count).to be(3)
      end
    end
  end

  describe "PUT /expenses/:id" do
    context "with valid parameters" do
      let(:expense_params) { { expense: { name: "Test Expense", amount: 90, split_type: "equal", currency: "INR", expense_date: Date.current, settled: false, payer_id: user.id, group_id: group.id, category_id: category.id } } }
      let(:expense) { create(:expense, payer: user, group: group, category: category) }

      it "updates an expense" do
        put expense_url(expense), params: expense_params

        response_body = Oj.load(response.body)
        expect(response).to be_successful
        expect(response_body).to eq({
          data: {
            id: expense.id.to_s,
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
              },
              expenses_users: {
                data: []
              }
            }
          }
        }.with_indifferent_access)
      end
    end
  end

  describe "DELETE /expenses/:id" do
    let!(:expense) { create(:expense, payer: user, group: group, category: category) }

    it("deletes the expense when id is provided") do
      delete expense_url(expense), as: :json

      response_body = Oj.load(response.body)
      expect(response).to be_successful
      expect(response_body).to eq({ "message" => "Expense was successfully deleted" })
      expect(Expense.exists?(expense.id)).to be false
    end
  end
end
