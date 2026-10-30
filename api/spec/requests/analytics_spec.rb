require "rails_helper"

RSpec.describe "Analytics", type: :request do
  let!(:me) { create(:user, first_name: "Milisha", last_name: "Saran", email_address: "me@example.com") }
  let!(:riya) { create(:user, first_name: "Riya", last_name: "K", email_address: "riya@example.com") }
  let!(:group) { create(:group, name: "Goa trip", user: me, user_ids: [ me.id, riya.id ]) }
  let!(:food) { create(:category, user: me, name: "Food", icon: "restaurant", color: "#EF9F27") }
  let!(:travel) { create(:category, user: me, name: "Travel", icon: "flight", color: "#AFA9EC") }
  let!(:riya_food) { create(:category, user: riya, name: "food", icon: "lunch_dining", color: "#000000") }

  def json
    Oj.load(response.body)
  end

  # Creates an expense with explicit shares: { user => amount }.
  def expense(name:, amount:, payer: me, category: food, shares: { me => amount }, date: Date.new(2026, 10, 10),
              currency: "INR", target_group: group)
    record = create(:expense, name: name, amount: amount, payer: payer, user: payer, category: category,
                              group: target_group, expense_date: date, currency: currency)
    shares.each { |user, share| create(:expenses_user, expense: record, user: user, amount: share) }
    record
  end

  def personal(name:, amount:, **options)
    expense(name: name, amount: amount, target_group: nil, **options)
  end

  around { |example| Timecop.freeze(Date.new(2026, 10, 30)) { example.run } }

  before { sign_in(me) }

  describe "GET /analytics" do
    it "returns my share per month, oldest first, with empty months filled in" do
      expense(name: "Dinner", amount: 3000, payer: riya, category: riya_food, shares: { me => 1000, riya => 2000 },
              date: Date.new(2026, 8, 3))
      expense(name: "Hotel", amount: 6000, category: travel, shares: { me => 3000, riya => 3000 }, date: Date.new(2026, 10, 2))
      personal(name: "Groceries", amount: 500, date: Date.new(2026, 10, 12))

      get analytics_url

      expect(response).to have_http_status(:ok)
      expect(json["scope"]).to eq("all")
      expect(json["months"].map { |m| [ m["month"], m["total"] ] }).to eq([
        [ "2026-08", "1000.0" ], [ "2026-09", "0.0" ], [ "2026-10", "3500.0" ]
      ])
      october = json["months"].last
      expect(october["categories"]).to eq([
        { "name" => "Travel", "icon" => "flight", "color" => "#AFA9EC", "amount" => "3000.0" },
        { "name" => "Food", "icon" => "restaurant", "color" => "#EF9F27", "amount" => "500.0" }
      ])
      # Riya's "food" merges into my "Food", shown with my icon and color.
      expect(json["months"].first["categories"]).to eq([
        { "name" => "Food", "icon" => "restaurant", "color" => "#EF9F27", "amount" => "1000.0" }
      ])
    end

    it "leaves out other currencies and counts them per month" do
      expense(name: "Dinner", amount: 400, date: Date.new(2026, 10, 5))
      expense(name: "Abroad", amount: 20, currency: "USD", date: Date.new(2026, 10, 6))
      expense(name: "Abroad 2", amount: 30, currency: "USD", date: Date.new(2026, 10, 7))

      get analytics_url

      expect(json["months"].map { |m| [ m["month"], m["total"], m["other_currency_count"] ] }).to eq([
        [ "2026-10", "400.0", 2 ]
      ])
    end

    it "keeps only group expenses for scope=groups" do
      expense(name: "Hotel", amount: 600, date: Date.new(2026, 10, 2))
      personal(name: "Groceries", amount: 500)

      get analytics_url, params: { scope: "groups" }

      expect(json["scope"]).to eq("groups")
      expect(json["months"].map { |m| m["total"] }).to eq([ "600.0" ])
    end

    it "keeps only personal expenses for scope=personal" do
      create(:friendship, user: me, friend: riya)
      expense(name: "Hotel", amount: 600, date: Date.new(2026, 10, 2))
      personal(name: "Groceries", amount: 500)
      personal(name: "Cab with Riya", amount: 200, shares: { me => 100, riya => 100 })

      get analytics_url, params: { scope: "personal" }

      expect(json["months"].map { |m| m["total"] }).to eq([ "500.0" ])
    end

    it "ignores expenses where I have no share" do
      expense(name: "Riya's lunch", amount: 300, payer: riya, shares: { riya => 300 })

      get analytics_url

      expect(json["months"]).to eq([])
    end

    it "rejects an unknown scope" do
      get analytics_url, params: { scope: "friends" }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "needs a signed-in user" do
      sign_out

      get analytics_url

      expect(response).to redirect_to(new_session_url)
    end
  end

  describe "GET /analytics/expenses" do
    it "lists my share of one category in one month, newest first" do
      dinner = expense(name: "Dinner", amount: 3000, payer: riya, category: riya_food,
                       shares: { me => 1000, riya => 2000 }, date: Date.new(2026, 10, 3))
      groceries = personal(name: "Groceries", amount: 500, date: Date.new(2026, 10, 12))
      expense(name: "Hotel", amount: 600, category: travel, date: Date.new(2026, 10, 2))
      personal(name: "Last month", amount: 90, date: Date.new(2026, 9, 30))
      expense(name: "Abroad", amount: 20, currency: "USD", date: Date.new(2026, 10, 6))

      get expenses_analytics_url, params: { month: "2026-10", category: "FOOD" }

      expect(response).to have_http_status(:ok)
      expect(json["expenses"]).to eq([
        { "id" => groceries.id, "name" => "Groceries", "expense_date" => "2026-10-12", "group_name" => nil, "my_share" => "500.0" },
        { "id" => dinner.id, "name" => "Dinner", "expense_date" => "2026-10-03", "group_name" => "Goa trip", "my_share" => "1000.0" }
      ])
    end

    it "applies the scope" do
      expense(name: "Dinner", amount: 300, date: Date.new(2026, 10, 3))
      personal(name: "Groceries", amount: 500)

      get expenses_analytics_url, params: { month: "2026-10", category: "Food", scope: "personal" }

      expect(json["expenses"].map { |e| e["name"] }).to eq([ "Groceries" ])
    end

    it "rejects a bad month" do
      get expenses_analytics_url, params: { month: "October", category: "Food" }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
