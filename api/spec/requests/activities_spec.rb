require "rails_helper"

RSpec.describe "Activities", type: :request do
  let!(:user) { create(:user, first_name: "Neha", last_name: "Kapoor") }
  let!(:riya) { create(:user, first_name: "Riya", last_name: "Shah") }
  let!(:outsider) { create(:user) }
  let!(:group) { create(:group, name: "Goa trip", user: user, user_ids: [ user.id, riya.id ]) }
  let!(:other_group) { create(:group, name: "Office", user: outsider, user_ids: [ outsider.id ]) }
  let!(:category) { create(:category, user: user) }

  def expense_in(group, name:, payer: user)
    create(:expense, name: name, payer: payer, user: payer, group: group, category: category).tap do |e|
      e.expenses_users.create!(user: payer, amount: e.amount)
    end
  end

  def record(expense, action: "created", group_id: expense.group_id)
    Activity.record!(actor: expense.payer, action: action, expense_id: expense.id, group_id: group_id,
                     before: action == "created" ? nil : expense.snapshot, after: action == "deleted" ? nil : expense.snapshot)
  end

  def data
    Oj.load(response.body)["data"]
  end

  it "needs a signed-in user" do
    get activities_url

    expect(response).to redirect_to(new_session_path)
  end

  context "when signed in" do
    before { sign_in(user) }

    it "returns entries the user may see, newest first" do
      older = Timecop.travel(1.hour.ago) { record(expense_in(group, name: "Hotel")) }
      newer = record(expense_in(group, name: "Coffee", payer: riya))
      record(expense_in(other_group, name: "Hidden", payer: outsider))

      get activities_url

      expect(response).to be_successful
      expect(data.map { |d| d["id"].to_i }).to eq([ newer.id, older.id ])
      expect(data.first["attributes"]).to include(
        "action" => "created",
        "expense_id" => newer.expense_id,
        "actor" => { "id" => riya.id, "name" => "Riya Shah" },
        "group" => { "id" => group.id, "name" => "Goa trip" },
        "before" => nil,
        "changed_fields" => []
      )
      expect(data.first["attributes"]["after"]["name"]).to eq("Coffee")
      expect(Oj.load(response.body)["meta"]).to include("current_page" => 1)
    end

    it "filters by group, and group_id=none returns friend expenses only" do
      in_group = record(expense_in(group, name: "Hotel"))
      friend = record(expense_in(nil, name: "Movie"))

      get activities_url, params: { group_id: group.id }
      expect(data.map { |d| d["id"].to_i }).to eq([ in_group.id ])

      get activities_url, params: { group_id: "none" }
      expect(data.map { |d| d["id"].to_i }).to eq([ friend.id ])
    end

    it "hides a group's entries once the user has left it" do
      record(expense_in(group, name: "Hotel"))
      group.group_memberships.find_by(user: user).update!(left_at: Date.current)

      get activities_url

      expect(data).to be_empty
    end

    it "still shows what a deleted expense was" do
      expense = expense_in(group, name: "Cab to airport", payer: riya)
      delete_entry = record(expense, action: "deleted")
      expense.destroy!

      get activities_url

      attributes = data.find { |d| d["id"].to_i == delete_entry.id }["attributes"]
      expect(attributes["before"]["payer"]["name"]).to eq("Riya Shah")
      expect(attributes["before"]["shares"].first["name"]).to eq("Riya Shah")
      expect(attributes["group"]["name"]).to eq("Goa trip")
    end
  end
end
