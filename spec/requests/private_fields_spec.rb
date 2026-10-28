require "rails_helper"

RSpec.describe "Private user fields", type: :request do
  let!(:me) { create(:user, phone: "111", date_of_birth: "1990-01-01") }
  let!(:mate) { create(:user, phone: "222", date_of_birth: "1991-02-02") }
  let!(:group) { create(:group, user: me, user_ids: [ me.id, mate.id ]) }

  def json
    Oj.load(response.body)
  end

  def attributes_of(user, included)
    included.find { |row| row["type"] == "user" && row["id"] == user.id.to_s }["attributes"]
  end

  before { sign_in(me) }

  it "hides a co-member's phone and date of birth in GET /groups/:id" do
    get group_url(group)

    expect(attributes_of(mate, json["included"]).keys).not_to include("phone", "date_of_birth")
    expect(attributes_of(me, json["included"])).to include("phone" => "111", "date_of_birth" => "1990-01-01")
  end

  it "hides a co-member's phone and date of birth in GET /groups" do
    get groups_url

    expect(attributes_of(mate, json["included"]).keys).not_to include("phone", "date_of_birth")
  end

  it "hides a co-member's phone and date of birth in the memberships list" do
    get group_group_memberships_url(group), as: :json

    expect(attributes_of(mate, json["included"]).keys).not_to include("phone", "date_of_birth")
    expect(attributes_of(me, json["included"])).to include("phone" => "111")
  end

  it "hides a payer's phone and date of birth in expenses" do
    category = create(:category, user: me)
    create(:expense, group: group, payer: mate, user: me, category: category)

    get expenses_url

    expect(attributes_of(mate, json["included"]).keys).not_to include("phone", "date_of_birth")
  end

  it "returns my own phone and date of birth from GET /me" do
    get me_url

    expect(json.dig("data", "attributes")).to include("phone" => "111", "date_of_birth" => "1990-01-01")
  end

  it "returns my own phone and date of birth from PATCH /me" do
    patch me_url, params: { user: { phone: "333" } }

    expect(json.dig("data", "attributes")).to include("phone" => "333", "date_of_birth" => "1990-01-01")
  end

  it "returns my own phone and date of birth from GET /session" do
    get session_url, as: :json

    expect(json.dig("data", "attributes")).to include("phone" => "111", "date_of_birth" => "1990-01-01")
  end

  it "returns my own phone and date of birth when I sign in" do
    sign_out
    post session_url, params: { email_address: mate.email_address, password: "password" }, as: :json

    expect(json.dig("data", "user", "data", "attributes")).to include("phone" => "222", "date_of_birth" => "1991-02-02")
  end

  it "returns my own phone and date of birth when I sign up" do
    sign_out
    invitation = create(:invitation, inviter: me, email: "new@example.com")

    post user_registers_url, params: { token: invitation.token, user: {
      email_address: "new@example.com", password: "secret12", password_confirmation: "secret12",
      first_name: "New", last_name: "One", phone: "444", date_of_birth: "2000-03-03"
    } }

    expect(json.dig("data", "attributes")).to include("phone" => "444", "date_of_birth" => "2000-03-03")
  end
end
