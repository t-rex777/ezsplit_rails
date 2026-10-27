require "rails_helper"

RSpec.describe "Balances and settlements", type: :request do
  let!(:alice) { create(:user, first_name: "Alice") }
  let!(:bob) { create(:user, first_name: "Bob") }
  let!(:carol) { create(:user, first_name: "Carol") }
  let!(:group) { create(:group, user: alice, user_ids: [ alice.id, bob.id, carol.id ]) }

  # Alice pays 90 for dinner, split equally: Bob and Carol each owe her 30.
  # Bob pays 20 for a cab in USD, split with Alice: Alice owes him 10 USD.
  before do
    create(:friendship, user: alice, friend: bob)
    create(:friendship, user: bob, friend: alice)

    dinner = create(:expense, group: group, payer: alice, user: alice, amount: 90, category: create(:category, user: alice))
    [ alice, bob, carol ].each { |u| dinner.expenses_users.create!(user: u, amount: 30) }

    cab = create(:expense, group: nil, payer: bob, user: bob, amount: 20, currency: "USD", category: create(:category, user: bob))
    [ alice, bob ].each { |u| cab.expenses_users.create!(user: u, amount: 10) }
  end

  def rows
    Oj.load(response.body)["data"].map { |r| [ r["user_id"], r["currency"], r["amount"] ] }
  end

  describe "GET /balances" do
    it "nets what each person owes me, per currency" do
      sign_in(alice)

      get balances_url

      expect(rows).to contain_exactly(
        [ bob.id, "INR", "30.0" ],
        [ carol.id, "INR", "30.0" ],
        [ bob.id, "USD", "-10.0" ]
      )
    end

    it "goes down after a settlement" do
      create(:settlement, payer: bob, payee: alice, amount: 30, currency: "INR", group: group)
      sign_in(alice)

      get balances_url

      expect(rows).to contain_exactly([ carol.id, "INR", "30.0" ], [ bob.id, "USD", "-10.0" ])
    end
  end

  describe "GET /groups/:id/balances" do
    it "shows each member's position in the group" do
      sign_in(bob)

      get balances_group_url(group)

      expect(rows).to contain_exactly(
        [ alice.id, "INR", "60.0" ],
        [ bob.id, "INR", "-30.0" ],
        [ carol.id, "INR", "-30.0" ]
      )
    end

    it "is hidden from people outside the group" do
      sign_in(create(:user))

      get balances_group_url(group)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /settlements" do
    it "records that I paid a friend back" do
      sign_in(alice)

      post settlements_url, params: { settlement: { payee_id: bob.id, amount: 10, currency: "USD" } }

      expect(response).to have_http_status(:created)
      get balances_url
      expect(rows).to contain_exactly([ bob.id, "INR", "30.0" ], [ carol.id, "INR", "30.0" ])
    end

    it "records a payment inside a group" do
      sign_in(carol)

      post settlements_url, params: { settlement: { payee_id: alice.id, amount: 30, currency: "INR", group_id: group.id } }

      expect(response).to have_http_status(:created)
      get balances_group_url(group)
      expect(rows).to contain_exactly([ alice.id, "INR", "30.0" ], [ bob.id, "INR", "-30.0" ])
    end

    it "rejects paying someone who is not a friend" do
      sign_in(alice)

      post settlements_url, params: { settlement: { payee_id: carol.id, amount: 30, currency: "INR" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Oj.load(response.body)["errors"]).to eq([ "Payee must be one of your friends" ])
    end

    it "rejects a zero amount" do
      sign_in(alice)

      post settlements_url, params: { settlement: { payee_id: bob.id, amount: 0, currency: "INR" } }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /settlements/:id" do
    it "lets only the payer delete it" do
      settlement = create(:settlement, payer: bob, payee: alice, amount: 30)

      sign_in(alice)
      delete settlement_url(settlement)
      expect(response).to have_http_status(:not_found)
      sign_out

      sign_in(bob)
      delete settlement_url(settlement)
      expect(response).to have_http_status(:ok)
      expect(Settlement.exists?(settlement.id)).to be false
    end
  end

  describe "GET /settlements" do
    it "lists settlements I am part of" do
      mine = create(:settlement, payer: bob, payee: alice)
      create(:settlement, payer: bob, payee: carol)
      sign_in(alice)

      get settlements_url

      expect(Oj.load(response.body)["data"].map { |s| s["id"] }).to eq([ mine.id.to_s ])
    end
  end
end
