require "rails_helper"

RSpec.describe "Expense rules", type: :request do
  let!(:alice) { create(:user, first_name: "Alice") }
  let!(:bob) { create(:user, first_name: "Bob") }
  let!(:carol) { create(:user, first_name: "Carol") }
  let!(:group) { create(:group, user: alice, user_ids: [ alice.id, bob.id ]) }
  let!(:category) { create(:category, user: alice) }

  def expense_params(overrides = {})
    {
      expense: {
        name: "Dinner",
        amount: 100,
        split_type: "equal",
        currency: "INR",
        expense_date: "2026-10-27",
        payer_id: alice.id,
        group_id: group.id,
        category_id: category.id,
        distribution: [ { user_id: alice.id }, { user_id: bob.id } ]
      }.merge(overrides)
    }
  end

  def share_amounts(expense_id)
    ExpensesUser.where(expense_id: expense_id).order(:user_id).pluck(:user_id, :amount).to_h.transform_values(&:to_s)
  end

  before { sign_in(alice) }

  describe "splitting with a friend, without a group" do
    it "creates the expense when everyone is a friend" do
      create(:friendship, user: alice, friend: bob)

      post expenses_url, params: expense_params(group_id: nil)

      expect(response).to have_http_status(:ok)
      expense = Expense.last
      expect(expense.group).to be_nil
      expect(share_amounts(expense.id)).to eq(alice.id => "50.0", bob.id => "50.0")
    end

    it "rejects people who are not friends" do
      post expenses_url, params: expense_params(group_id: nil, distribution: [ { user_id: alice.id }, { user_id: carol.id } ])

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Oj.load(response.body)["errors"]).to eq([ "Everyone in the expense must be you or one of your friends" ])
    end
  end

  describe "permissions" do
    it "rejects split members who are not in the group" do
      post expenses_url, params: expense_params(distribution: [ { user_id: alice.id }, { user_id: carol.id } ])

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Oj.load(response.body)["errors"]).to eq([ "Everyone in the expense must be a member of the group" ])
    end

    it "rejects a group the user is not a member of" do
      other_group = create(:group, user: carol, user_ids: [ carol.id ])

      post expenses_url, params: expense_params(group_id: other_group.id)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Oj.load(response.body)["errors"]).to eq([ "Group not found" ])
    end

    it "rejects another user's category" do
      post expenses_url, params: expense_params(category_id: create(:category, user: carol).id)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Oj.load(response.body)["errors"]).to eq([ "Category not found" ])
    end

    it "rejects a split without a distribution" do
      post expenses_url, params: expense_params(distribution: nil)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Oj.load(response.body)["errors"]).to eq([ "Distribution is required" ])
    end

    it "rejects the same person twice" do
      post expenses_url, params: expense_params(distribution: [ { user_id: bob.id }, { user_id: bob.id } ])

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Oj.load(response.body)["errors"]).to eq([ "Each person can appear only once in the distribution" ])
    end
  end

  describe "split math" do
    let!(:group) { create(:group, user: alice, user_ids: [ alice.id, bob.id, carol.id ]) }

    it "splits 100 equally among 3 to the cent" do
      post expenses_url, params: expense_params(distribution: [ alice, bob, carol ].map { |u| { user_id: u.id } })

      expect(response).to have_http_status(:ok)
      expect(share_amounts(Expense.last.id)).to eq(alice.id => "33.34", bob.id => "33.33", carol.id => "33.33")
    end

    it "splits by percentage so the shares add up to the total" do
      post expenses_url, params: expense_params(
        amount: 10, split_type: "percentage",
        distribution: [ { user_id: alice.id, amount: 33.33 }, { user_id: bob.id, amount: 33.33 }, { user_id: carol.id, amount: 33.34 } ]
      )

      expect(response).to have_http_status(:ok)
      expect(ExpensesUser.where(expense_id: Expense.last.id).sum(:amount)).to eq(10)
    end

    it "rejects exact amounts that don't add up" do
      post expenses_url, params: expense_params(
        split_type: "exact",
        distribution: [ { user_id: alice.id, amount: 60 }, { user_id: bob.id, amount: 30 } ]
      )

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Oj.load(response.body)["errors"]).to eq([ "Amount must be equal to the sum of the distribution" ])
    end
  end

  describe "updating" do
    before { post expenses_url, params: expense_params }
    let(:expense) { Expense.last }

    it "renames without resending the split and keeps the shares" do
      patch expense_url(expense), params: { expense: { name: "Lunch" } }

      expect(response).to have_http_status(:ok)
      expect(expense.reload.name).to eq("Lunch")
      expect(share_amounts(expense.id)).to eq(alice.id => "50.0", bob.id => "50.0")
    end

    it "requires the split when the amount changes" do
      patch expense_url(expense), params: { expense: { amount: 300 } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Oj.load(response.body)["errors"]).to eq([ "Distribution is required when amount or split type changes" ])
      expect(expense.reload.amount).to eq(100)
    end

    it "recalculates shares when the amount and split are sent" do
      patch expense_url(expense), params: expense_params(amount: 300)

      expect(response).to have_http_status(:ok)
      expect(share_amounts(expense.id)).to eq(alice.id => "150.0", bob.id => "150.0")
    end
  end

  describe "visibility" do
    before { post expenses_url, params: expense_params }

    it "shows the expense to people in the split" do
      sign_out
      sign_in(bob)

      get expenses_url
      expect(Oj.load(response.body)["data"].map { |e| e["id"] }).to eq([ Expense.last.id.to_s ])

      get expense_url(Expense.last)
      expect(response).to have_http_status(:ok)
    end

    it "does not let people in the split edit it" do
      sign_out
      sign_in(bob)

      patch expense_url(Expense.last), params: { expense: { name: "Mine now" } }
      expect(response).to have_http_status(:not_found)
    end

    it "hides the expense from people outside it" do
      sign_out
      sign_in(carol)

      get expense_url(Expense.last)
      expect(response).to have_http_status(:not_found)
    end
  end
end
