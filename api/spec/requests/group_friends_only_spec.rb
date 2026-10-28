require "rails_helper"

RSpec.describe "Groups only contain friends", type: :request do
  let!(:me) { create(:user) }
  let!(:friend) { create(:user) }
  let!(:stranger) { create(:user) }
  let(:error) { { "errors" => [ "You can only add friends to a group." ] } }

  before do
    create(:friendship, user: me, friend: friend)
    sign_in(me)
  end

  describe "POST /groups" do
    it "lets me add myself and my friends" do
      post groups_url, params: { group: { name: "Trip", user_ids: [ me.id, friend.id ] } }

      expect(response).to have_http_status(:created)
      expect(Group.last.users).to contain_exactly(me, friend)
    end

    it "counts a friendship in either direction" do
      other = create(:user)
      create(:friendship, user: other, friend: me)

      post groups_url, params: { group: { name: "Trip", user_ids: [ other.id ] } }

      expect(response).to have_http_status(:created)
    end

    it "refuses a non-friend and creates nothing" do
      expect {
        post groups_url, params: { group: { name: "Trip", user_ids: [ me.id, stranger.id ] } }
      }.not_to change(Group, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Oj.load(response.body)).to eq(error)
      expect(GroupMembership.count).to eq(0)
    end
  end

  describe "PUT /groups/:id" do
    let!(:group) { create(:group, user: me, user_ids: [ me.id ]) }

    it "adds a friend" do
      put group_url(group), params: { group: { user_ids: [ me.id, friend.id ] } }

      expect(response).to have_http_status(:ok)
      expect(group.reload.users).to contain_exactly(me, friend)
    end

    it "refuses a non-friend and changes nothing" do
      put group_url(group), params: { group: { name: "Renamed", user_ids: [ me.id, stranger.id ] } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Oj.load(response.body)).to eq(error)
      expect(group.reload.name).to eq("Test Group")
      expect(group.users).to contain_exactly(me)
    end

    it "keeps a current member who is not a friend" do
      group.group_memberships.create!(user: stranger)

      put group_url(group), params: { group: { user_ids: [ me.id, stranger.id, friend.id ] } }

      expect(response).to have_http_status(:ok)
      expect(group.reload.users).to contain_exactly(me, stranger, friend)
    end
  end

  describe "POST /groups/:id/add_members" do
    let!(:group) { create(:group, user: me, user_ids: [ me.id ]) }

    it "adds a friend" do
      post add_members_group_url(group), params: { group: { user_ids: [ me.id, friend.id ] } }

      expect(response).to have_http_status(:ok)
      expect(group.reload.users).to contain_exactly(me, friend)
    end

    it "refuses a non-friend and changes nothing" do
      post add_members_group_url(group), params: { group: { user_ids: [ me.id, friend.id, stranger.id ] } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Oj.load(response.body)).to eq(error)
      expect(group.reload.users).to contain_exactly(me)
    end
  end

  describe "POST /groups/:id/group_memberships" do
    let!(:group) { create(:group, user: me, user_ids: [ me.id ]) }

    it "adds a friend" do
      post group_group_memberships_url(group), params: { group_membership: { user_id: friend.id } }, as: :json

      expect(response).to have_http_status(:created)
      expect(group.reload.users).to contain_exactly(me, friend)
    end

    it "refuses a non-friend and changes nothing" do
      post group_group_memberships_url(group), params: { group_membership: { user_id: stranger.id } }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Oj.load(response.body)["errors"]).to eq(error["errors"])
      expect(group.reload.users).to contain_exactly(me)
    end

    it "lets an active member who is not a friend stay" do
      group.group_memberships.create!(user: stranger)

      post group_group_memberships_url(group), params: { group_membership: { user_id: stranger.id } }, as: :json

      expect(response).to have_http_status(:created)
    end
  end
end
