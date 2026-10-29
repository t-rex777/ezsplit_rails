require "rails_helper"

RSpec.describe "Activity recording", type: :request do
  let!(:user) { create(:user) }
  let!(:second_user) { create(:user) }
  let!(:third_user) { create(:user) }
  let!(:group) { create(:group, user: user, user_ids: [ user.id, second_user.id, third_user.id ]) }
  let!(:category) { create(:category, user: user) }

  let(:expense_params) do
    {
      expense: {
        name: "Test Expense", amount: 90, split_type: "exact", currency: "INR", expense_date: "2025-08-30",
        payer_id: user.id, group_id: group.id, category_id: category.id,
        distribution: [
          { user_id: user.id, amount: 30 },
          { user_id: second_user.id, amount: 30 },
          { user_id: third_user.id, amount: 30 }
        ]
      }
    }
  end

  before { sign_in(user) }

  def create_expense
    post expenses_url, params: expense_params
    Expense.last
  end

  def params_with(overrides)
    { expense: expense_params[:expense].merge(overrides) }
  end

  it "records a created entry" do
    expect { create_expense }.to change(Activity, :count).by(1)

    activity = Activity.last
    expect(activity).to have_attributes(action: "created", actor_id: user.id, group_id: group.id, before_snapshot: nil)
    expect(activity.after_snapshot["name"]).to eq("Test Expense")
  end

  it "records an updated entry with the expense as it was before" do
    expense = create_expense
    patch expense_url(expense), params: params_with(amount: 120, distribution: [
      { user_id: user.id, amount: 40 }, { user_id: second_user.id, amount: 40 }, { user_id: third_user.id, amount: 40 }
    ])

    expect(response).to be_successful
    activity = Activity.where(action: "updated").sole
    expect(activity.before_snapshot["amount"]).to eq("90.0")
    expect(activity.after_snapshot["amount"]).to eq("120.0")
    expect(activity.after_snapshot["shares"].map { |s| s["amount"] }).to eq(%w[40.0 40.0 40.0])
    expect(activity.changed_fields).to eq(%w[amount shares])
  end

  it "records a split-only edit as a change to shares" do
    expense = create_expense
    patch expense_url(expense), params: params_with(distribution: [
      { user_id: user.id, amount: 60 }, { user_id: second_user.id, amount: 15 }, { user_id: third_user.id, amount: 15 }
    ])

    expect(Activity.where(action: "updated").sole.changed_fields).to eq([ "shares" ])
  end

  it "records nothing for an edit that changes nothing" do
    expense = create_expense

    expect { patch expense_url(expense), params: expense_params }.not_to change(Activity, :count)
    expect(response).to be_successful
  end

  it "records nothing when the edit is rejected" do
    expense = create_expense

    expect {
      patch expense_url(expense), params: params_with(amount: 100)
    }.not_to change(Activity, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "records a deleted entry that keeps the removed expense" do
    expense = create_expense

    expect { delete expense_url(expense) }.to change(Activity, :count).by(1)

    activity = Activity.last
    expect(activity).to have_attributes(action: "deleted", expense_id: expense.id, after_snapshot: nil)
    expect(activity.before_snapshot["name"]).to eq("Test Expense")
    expect(activity.before_snapshot["shares"].size).to eq(3)
  end
end
