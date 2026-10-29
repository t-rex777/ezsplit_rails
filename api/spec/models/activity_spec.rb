require "rails_helper"

RSpec.describe Activity, type: :model do
  let!(:riya) { create(:user, first_name: "Riya", last_name: "Shah") }
  let!(:arjun) { create(:user, first_name: "Arjun", last_name: "Mehta") }
  let!(:outsider) { create(:user) }
  let!(:group) { create(:group, name: "Goa trip", user: riya, user_ids: [ riya.id, arjun.id ]) }
  let!(:category) { create(:category, name: "Food", icon: "restaurant", color: "peach", user: riya) }
  let!(:expense) do
    create(:expense, name: "Beach dinner", amount: 90, payer: riya, user: riya, group: group, category: category).tap do |e|
      e.expenses_users.create!(user: riya, amount: 45)
      e.expenses_users.create!(user: arjun, amount: 45)
    end
  end

  describe "Expense#snapshot" do
    it "copies names so the entry stays readable after a delete" do
      snapshot = expense.snapshot

      expect(snapshot["name"]).to eq("Beach dinner")
      expect(snapshot["amount"]).to eq("90.0")
      expect(snapshot["payer"]).to eq({ "id" => riya.id, "name" => "Riya Shah" })
      expect(snapshot["category"]).to include("name" => "Food", "icon" => "restaurant")
      expect(snapshot["group"]).to eq({ "id" => group.id, "name" => "Goa trip" })
      expect(snapshot["shares"]).to eq([
        { "user_id" => riya.id, "name" => "Riya Shah", "amount" => "45.0" },
        { "user_id" => arjun.id, "name" => "Arjun Mehta", "amount" => "45.0" }
      ])
    end
  end

  describe ".record!" do
    it "writes nothing for an update that changed nothing" do
      snapshot = expense.snapshot
      result = Activity.record!(actor: riya, action: "updated", expense_id: expense.id, group_id: group.id, before: snapshot, after: snapshot)

      expect(result).to be_nil
      expect(Activity.count).to eq(0)
    end

    it "adds the payer, creator, actor, and everyone in the split as participants" do
      activity = Activity.record!(actor: arjun, action: "created", expense_id: expense.id, group_id: group.id, before: nil, after: expense.snapshot)

      expect(activity.participant_ids).to match_array([ riya.id, arjun.id ])
    end
  end

  describe "#changed_fields" do
    it "lists the top-level keys that differ" do
      before = expense.snapshot
      after = before.merge("amount" => "120.0", "shares" => [])
      activity = Activity.record!(actor: riya, action: "updated", expense_id: expense.id, group_id: group.id, before: before, after: after)

      expect(activity.changed_fields).to eq([ "amount", "shares" ])
    end

    it "is empty for a created entry" do
      activity = Activity.record!(actor: riya, action: "created", expense_id: expense.id, group_id: group.id, before: nil, after: expense.snapshot)

      expect(activity.changed_fields).to eq([])
    end
  end

  describe ".visible_to" do
    let!(:group_entry) do
      Activity.record!(actor: riya, action: "created", expense_id: expense.id, group_id: group.id, before: nil, after: expense.snapshot)
    end
    let!(:friend_entry) do
      Activity.record!(actor: riya, action: "created", expense_id: 999, group_id: nil, before: nil, after: expense.snapshot.merge("group" => nil))
    end

    it "shows group entries to active members and friend entries to participants" do
      expect(Activity.visible_to(arjun)).to match_array([ group_entry, friend_entry ])
      expect(Activity.visible_to(outsider)).to be_empty
    end

    it "hides group entries from a member who left" do
      group.group_memberships.find_by(user: arjun).update!(left_at: Date.current)

      expect(Activity.visible_to(arjun)).to eq([ friend_entry ])
    end
  end
end
