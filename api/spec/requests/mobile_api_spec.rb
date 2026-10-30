require "rails_helper"

# Endpoints and rules the Flutter app depends on.
RSpec.describe "Mobile API", type: :request do
  let!(:me) { create(:user, first_name: "Milisha", last_name: "Saran", email_address: "me@example.com") }
  let!(:riya) { create(:user, first_name: "Riya", last_name: "K", email_address: "riya@example.com") }
  let!(:arjun) { create(:user, first_name: "Arjun", last_name: "M", email_address: "arjun@example.com") }
  let!(:group) { create(:group, name: "Goa trip", user: me, user_ids: [ me.id, riya.id, arjun.id ]) }
  let!(:food) { create(:category, user: me, name: "Food", icon: "restaurant", color: "#FAC775") }
  let!(:travel) { create(:category, user: me, name: "Travel", icon: "flight", color: "#AFA9EC") }
  let!(:riya_food) { create(:category, user: riya, name: "food", icon: "lunch_dining", color: "#000000") }
  let!(:riya_misc) { create(:category, user: riya, name: "Snacks", icon: "cookie", color: "#F4C0D1") }

  def json
    Oj.load(response.body)
  end

  # Creates an expense with explicit shares: { user => amount }.
  def expense(name:, amount:, payer:, category:, shares:, date: Date.current, currency: "INR", creator: payer, target_group: group)
    record = create(:expense, name: name, amount: amount, payer: payer, user: creator, category: category,
                              group: target_group, expense_date: date, currency: currency)
    shares.each { |user, share| create(:expenses_user, expense: record, user: user, amount: share) }
    record
  end

  before { sign_in(me) }

  describe "mobile user agent" do
    it "lets the Dart HTTP client log in with JSON" do
      sign_out
      post session_url,
        params: { email_address: me.email_address, password: me.password }.to_json,
        headers: { "User-Agent" => "Dart/3.5 (dart:io)", "Accept" => "application/json", "Content-Type" => "application/json" }

      expect(response).to have_http_status(:ok)
      expect(json.dig("data", "user", "data", "attributes", "email_address")).to eq("me@example.com")
    end
  end

  describe "expense notes and creator" do
    it "saves notes and returns notes and creator_id" do
      post expenses_url, params: { expense: {
        name: "Dinner", amount: "300", split_type: "equal", currency: "INR", expense_date: Date.current,
        payer_id: me.id, group_id: group.id, category_id: food.id, notes: "Includes tip",
        distribution: [ { user_id: me.id }, { user_id: riya.id }, { user_id: arjun.id } ]
      } }

      expect(response).to have_http_status(:ok)
      attributes = json.dig("data", "attributes")
      expect(attributes["notes"]).to eq("Includes tip")
      expect(attributes["creator_id"]).to eq(me.id)
    end
  end

  describe "GET /expenses filters" do
    let!(:dinner) { expense(name: "Beach dinner", amount: 3000, payer: me, category: food, shares: { me => 1000, riya => 1000, arjun => 1000 }, date: Date.new(2026, 10, 24)) }
    let!(:cab) { expense(name: "Cab", amount: 900, payer: riya, category: riya_misc, shares: { me => 300, riya => 300, arjun => 300 }, date: Date.new(2026, 10, 20)) }
    let!(:hotel) { expense(name: "Hotel", amount: 9000, payer: me, category: travel, shares: { me => 3000, riya => 3000, arjun => 3000 }, date: Date.new(2026, 9, 30)) }

    def names
      json["data"].map { |row| row.dig("attributes", "name") }
    end

    it "searches by name, ignoring case" do
      get expenses_url, params: { q: "DINNER" }
      expect(names).to eq([ "Beach dinner" ])
    end

    it "filters by category ids" do
      get expenses_url, params: { category_ids: [ food.id, travel.id ] }
      expect(names).to contain_exactly("Beach dinner", "Hotel")
    end

    it "filters by who paid" do
      get expenses_url, params: { paid_by: "me" }
      expect(names).to contain_exactly("Beach dinner", "Hotel")

      get expenses_url, params: { paid_by: "others" }
      expect(names).to eq([ "Cab" ])
    end

    it "filters by an inclusive date range" do
      get expenses_url, params: { from: "2026-10-20", to: "2026-10-24" }
      expect(names).to contain_exactly("Beach dinner", "Cab")
    end

    it "sorts" do
      get expenses_url, params: { sort: "amount_desc" }
      expect(names).to eq([ "Hotel", "Beach dinner", "Cab" ])

      get expenses_url, params: { sort: "oldest" }
      expect(names).to eq([ "Hotel", "Cab", "Beach dinner" ])

      get expenses_url, params: { sort: "nonsense" }
      expect(names).to eq([ "Beach dinner", "Cab", "Hotel" ])
    end
  end

  describe "GET /summary" do
    before do
      expense(name: "Dinner", amount: 3000, payer: me, category: food, shares: { me => 1000, riya => 1000, arjun => 1000 }, date: Date.new(2026, 10, 24))
      expense(name: "Lunch", amount: 600, payer: riya, category: riya_food, shares: { me => 300, riya => 300 }, date: Date.new(2026, 10, 5))
      expense(name: "Snack", amount: 100, payer: riya, category: riya_misc, shares: { me => 50, riya => 50 }, date: Date.new(2026, 10, 6))
      expense(name: "Hotel", amount: 9000, payer: me, category: travel, shares: { me => 3000, riya => 3000, arjun => 3000 }, date: Date.new(2026, 9, 30))
      expense(name: "Souvenir", amount: 20, payer: riya, category: riya_misc, shares: { me => 12, riya => 8 }, date: Date.new(2026, 10, 7), currency: "USD")
    end

    it "returns my share by category for the month and overall balances" do
      get summary_url, params: { month: "2026-10" }

      expect(response).to have_http_status(:ok)
      expect(json["month"]).to eq("2026-10")
      expect(json["my_share"]).to eq("1350.0")
      expect(json["categories"]).to eq([
        { "name" => "Food", "icon" => "restaurant", "color" => "#FAC775", "amount" => "1300.0" },
        { "name" => "Snacks", "icon" => "cookie", "color" => "#F4C0D1", "amount" => "50.0" }
      ])
      # Riya owes me 1000 + 3000, I owe Riya 300 + 50; Arjun owes me 1000 + 3000.
      expect(json["owed_to_you"]).to eq("7650.0")
      expect(json["you_owe"]).to eq("0.0")
      expect(json["other_currencies"]).to eq([ { "currency" => "USD", "you_owe" => "12.0", "owed_to_you" => "0.0" } ])
    end

    it "rejects a malformed month" do
      get summary_url, params: { month: "October" }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "personal expenses" do
    let!(:friendship) { create(:friendship, user: me, friend: riya) }

    def personal(name:, amount:, date: Date.new(2026, 10, 10), currency: "INR")
      expense(name: name, amount: amount, payer: me, category: food, shares: { me => amount },
              date: date, currency: currency, target_group: nil)
    end

    it "creates one without a group" do
      post expenses_url, params: { expense: {
        name: "Groceries", amount: "540", split_type: "equal", currency: "INR", expense_date: "2026-10-30",
        payer_id: me.id, category_id: food.id, distribution: [ { user_id: me.id, amount: 1 } ]
      } }

      expect(response).to have_http_status(:ok)
      created = Expense.last
      expect(created.group_id).to be_nil
      expect(created.expenses_users.pluck(:user_id, :amount)).to eq([ [ me.id, BigDecimal("540") ] ])
    end

    it "lists only expenses outside groups that only I am in" do
      mine = personal(name: "Groceries", amount: 540)
      expense(name: "Cab with Riya", amount: 200, payer: me, category: food, shares: { me => 100, riya => 100 }, target_group: nil)
      expense(name: "Dinner", amount: 300, payer: me, category: food, shares: { me => 300 })

      get expenses_url, params: { personal: "true" }

      expect(response).to have_http_status(:ok)
      expect(json["data"].map { |row| row["id"].to_i }).to eq([ mine.id ])
    end

    it "adds the month's personal total and count to the summary" do
      personal(name: "Groceries", amount: 540)
      personal(name: "Coffee", amount: 180)
      personal(name: "Last month", amount: 999, date: Date.new(2026, 9, 30))
      personal(name: "Abroad", amount: 5, currency: "USD")

      get summary_url, params: { month: "2026-10" }

      expect(json["personal_total"]).to eq("720.0")
      expect(json["personal_count"]).to eq(2)
      expect(json["my_share"]).to eq("720.0")
    end
  end

  describe "GET /groups/:id/totals" do
    before do
      expense(name: "Dinner", amount: 3000, payer: riya, category: riya_food, shares: { me => 1000, riya => 1000, arjun => 1000 })
      expense(name: "Hotel", amount: 9000, payer: me, category: travel, shares: { me => 3000, riya => 3000, arjun => 3000 })
    end

    it "returns group totals for members" do
      get totals_group_url(group)

      expect(response).to have_http_status(:ok)
      expect(json["total_spent"]).to eq("12000.0")
      expect(json["my_share"]).to eq("4000.0")
      expect(json["i_paid"]).to eq("9000.0")
      expect(json["categories"].map { |row| [ row["name"], row["amount"] ] }).to eq([ [ "Travel", "9000.0" ], [ "Food", "3000.0" ] ])
      expect(json["paid_by"].map { |row| [ row["first_name"], row["amount"] ] }).to eq([ [ "Milisha", "9000.0" ], [ "Riya", "3000.0" ] ])
    end

    it "hides other groups" do
      other = create(:group, user: riya, user_ids: [ riya.id ])
      get totals_group_url(other)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "group list fields" do
    it "adds owner_id, my_net and last_activity_at, newest activity first" do
      quiet = create(:group, name: "Quiet", user: riya, user_ids: [ me.id, riya.id ])
      quiet.update_columns(updated_at: 3.days.ago)
      group.update_columns(updated_at: 5.days.ago)
      expense(name: "Dinner", amount: 3000, payer: me, category: food, shares: { me => 1000, riya => 1000, arjun => 1000 })
      create(:settlement, payer: riya, payee: me, amount: 400, group: group)

      get groups_url

      rows = json["data"].map { |row| row["attributes"] }
      expect(rows.map { |row| row["name"] }).to eq([ "Goa trip", "Quiet" ])
      expect(rows.first["owner_id"]).to eq(me.id)
      expect(rows.first["my_net"]).to eq("1600.0")
      expect(rows.last["my_net"]).to eq("0.0")
      expect(rows.first["last_activity_at"]).to be_present
    end
  end

  describe "GET and PATCH /me" do
    it "returns the current user" do
      get me_url
      expect(json.dig("data", "attributes", "email_address")).to eq("me@example.com")
    end

    it "updates allowed fields and ignores email" do
      patch me_url, params: { user: { first_name: "Mili", phone: "9999999999", date_of_birth: "1996-03-12", email_address: "new@example.com" } }

      expect(response).to have_http_status(:ok)
      me.reload
      expect(me.first_name).to eq("Mili")
      expect(me.phone).to eq("9999999999")
      expect(me.email_address).to eq("me@example.com")
    end

    it "returns validation errors" do
      patch me_url, params: { user: { first_name: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json["errors"]).to include("First name can't be blank")
    end
  end

  describe "invite-only sign-up" do
    let!(:invitation) { create(:invitation, inviter: me, email: "neha@example.com") }
    let(:user_params) do
      { email_address: "neha@example.com", password: "secret123", password_confirmation: "secret123",
        first_name: "Neha", last_name: "K", phone: "9876543210", date_of_birth: "2000-05-01" }
    end

    before { sign_out }

    it "signs up with a valid invite and becomes friends with the inviter" do
      post user_registers_url, params: { token: invitation.token, user: user_params }

      expect(response).to have_http_status(:ok)
      neha = User.find_by(email_address: "neha@example.com")
      expect(neha.all_friends).to include(me)
      expect(invitation.reload).to be_accepted
    end

    it "refuses sign-up without a token" do
      expect { post user_registers_url, params: { user: user_params } }.not_to change(User, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json["errors"]).to eq([ "A valid invite is required to sign up" ])
    end

    it "refuses an invite sent to another email" do
      post user_registers_url, params: { token: invitation.token, user: user_params.merge(email_address: "other@example.com") }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(User.find_by(email_address: "other@example.com")).to be_nil
    end

    it "refuses an expired invite" do
      invitation.update_columns(expires_at: 1.day.ago)
      post user_registers_url, params: { token: invitation.token, user: user_params }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "keeps the invite pending when the user is invalid" do
      post user_registers_url, params: { token: invitation.token, user: user_params.merge(phone: "") }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(invitation.reload).to be_pending
    end
  end

  describe "GET /register" do
    it "links to the app with the invite" do
      sign_out
      get "/register", params: { token: "abc", email_address: "neha@example.com" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ezsplit://register?token=abc&amp;email_address=neha%40example.com")
    end
  end

  describe "leaving a group" do
    it "stops a member with an open balance from leaving" do
      expense(name: "Dinner", amount: 300, payer: me, category: food, shares: { me => 100, riya => 100, arjun => 100 })
      sign_out
      sign_in(riya)

      membership = group.group_memberships.find_by(user: riya)
      delete group_group_membership_url(group, membership), as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json["errors"]).to eq([ "Settle up before leaving" ])
      expect(membership.reload.left_at).to be_nil
    end

    it "lets a settled member leave" do
      sign_out
      sign_in(riya)
      membership = group.group_memberships.find_by(user: riya)
      delete group_group_membership_url(group, membership), as: :json

      expect(response).to have_http_status(:ok)
      expect(membership.reload.left_at).to be_present
    end

    it "stops the owner from leaving" do
      membership = group.group_memberships.find_by(user: me)
      delete group_group_membership_url(group, membership), as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json["errors"]).to eq([ "The owner can't leave. Delete the group instead." ])
    end
  end
end
