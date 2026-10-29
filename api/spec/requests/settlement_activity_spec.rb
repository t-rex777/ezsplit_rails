require "rails_helper"

RSpec.describe "Settlement activity", type: :request do
  let!(:payer) { create(:user, first_name: "Arjun", last_name: "Mehta") }
  let!(:payee) { create(:user, first_name: "Neha", last_name: "Kapoor") }
  let!(:member) { create(:user) }
  let!(:outsider) { create(:user) }
  let!(:group) { create(:group, name: "Goa trip", user: payer, user_ids: [ payer.id, payee.id, member.id ]) }

  def settle(params)
    post settlements_url, params: { settlement: { currency: "INR", settled_on: "2026-10-29" }.merge(params) }
  end

  before { sign_in(payer) }

  it "records who paid whom, how much, and in which group" do
    expect { settle(payee_id: payee.id, amount: 500, group_id: group.id, notes: "UPI") }.to change(Activity, :count).by(1)

    activity = Activity.last
    expect(activity).to have_attributes(action: "settled", actor_id: payer.id, group_id: group.id, expense_id: nil,
                                        settlement_id: Settlement.last.id, before_snapshot: nil)
    expect(activity.after_snapshot).to include(
      "amount" => "500.0", "currency" => "INR", "settled_on" => "2026-10-29", "notes" => "UPI",
      "payer" => { "id" => payer.id, "name" => "Arjun Mehta" },
      "payee" => { "id" => payee.id, "name" => "Neha Kapoor" },
      "group" => { "id" => group.id, "name" => "Goa trip" }
    )
  end

  it "records nothing when the settlement is rejected" do
    expect { settle(payee_id: outsider.id, amount: 500, group_id: group.id) }.not_to change(Activity, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "shows a group settlement to every member, and a friend settlement only to the two people" do
    create(:friendship, user: payer, friend: payee)
    settle(payee_id: payee.id, amount: 500, group_id: group.id)
    settle(payee_id: payee.id, amount: 200)

    expect(Activity.visible_to(member).pluck(:action)).to eq([ "settled" ])
    expect(Activity.visible_to(payee).count).to eq(2)
    expect(Activity.visible_to(outsider)).to be_empty
  end

  it "lists the settlement in GET /activities with its settlement_id" do
    settle(payee_id: payee.id, amount: 500, group_id: group.id)

    get activities_url

    attributes = Oj.load(response.body)["data"].first["attributes"]
    expect(attributes).to include("action" => "settled", "settlement_id" => Settlement.last.id, "expense_id" => nil)
    expect(attributes["after"]["payee"]["name"]).to eq("Neha Kapoor")
  end
end
