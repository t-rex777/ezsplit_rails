require "rails_helper"

RSpec.describe ExpensesController, type: :controller do
   before do
    # Create and set session for user1
    session = user.sessions.create!(user_agent: "test", ip_address: "127.0.0.1")
    cookies.signed[:session_id] = session.id
  end

  let!(:user) { create(:user) }
  let!(:group) { create(:group, created_by: user) }
  let!(:category) { create(:category, created_by: user) }

  describe "GET #index" do
    let!(:expenses) { create_list(:expense, 10, payer: user, group: group, category: category) }

    it "returns all the expenses" do
      get :index

      response_body = Oj.load(response.body)
      expect(response).to be_successful
      expect(response_body["data"].length).to eq(10)
    end
  end

  describe "POST #create" do
    context "with valid parameters" do
      let(:expense_params) { { expense: { name: "Test Expense", amount: 100, split_type: "equal", currency: "INR", expense_date: Date.current, settled: false, payer_id: user.id, group_id: group.id, category_id: category.id } } }

      it "creates a new expense" do
        post :create, params: expense_params

        response_body = Oj.load(response.body)
        expect(response).to be_successful
        expect(response_body).to eq({
          data: {
            id: "1",
            type: "expense",
            attributes: {
              name: "Test Expense",
              amount: "100.0",
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
    end
  end

   describe "PUT #update" do
    context "with valid parameters" do
      let(:expense_params) { { expense: { name: "Test Expense", amount: 100, split_type: "equal", currency: "INR", expense_date: Date.current, settled: false, payer_id: user.id, group_id: group.id, category_id: category.id } } }
      let(:expense) { create(:expense, payer: user, group: group, category: category) }

      it "updates an expense" do
        put :update, params: { id: expense.id, expense: expense_params.merge(name: "Updated Expense", settled: false) }

        response_body = Oj.load(response.body)
        expect(response).to be_successful
        expect(response_body).to eq({
          data: {
            id: expense.id.to_s,
            type: "expense",
            attributes: {
              name: "Updated Expense",
              amount: "100.0",
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
    end
  end
end
