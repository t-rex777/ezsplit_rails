require "rails_helper"

RSpec.describe "Group access", type: :request do
  let!(:owner) { create(:user) }
  let!(:member) { create(:user) }
  let!(:outsider) { create(:user) }
  let!(:group) { create(:group, user: owner, user_ids: [ owner.id, member.id ]) }

  describe "groups" do
    it "lets a member see a group they joined" do
      sign_in(member)

      get groups_url
      expect(Oj.load(response.body)["data"].map { |g| g["id"] }).to eq([ group.id.to_s ])

      get group_url(group)
      expect(response).to have_http_status(:ok)
    end

    it "does not let a member edit or delete the group" do
      sign_in(member)

      put group_url(group), params: { group: { name: "Taken over" } }
      expect(response).to have_http_status(:not_found)

      delete group_url(group)
      expect(response).to have_http_status(:not_found)
    end

    it "adds the creator as a member" do
      sign_in(outsider)

      post groups_url, params: { group: { name: "Trip" } }

      expect(response).to have_http_status(:created)
      expect(Group.last.users).to eq([ outsider ])
    end

    it "hides members who left" do
      group.group_memberships.find_by(user: member).update!(left_at: Date.current)
      sign_in(owner)

      get group_url(group)
      user_ids = Oj.load(response.body)["data"]["relationships"]["users"]["data"].map { |u| u["id"] }
      expect(user_ids).to eq([ owner.id.to_s ])
    end

    it "does not delete a group that has expenses" do
      create(:expense, group: group, payer: owner, user: owner, category: create(:category, user: owner))
      sign_in(owner)

      delete group_url(group)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Group.exists?(group.id)).to be true
    end

    it "adds members through add_members" do
      sign_in(owner)

      post add_members_group_url(group), params: { group: { user_ids: [ owner.id, member.id, outsider.id ] } }

      expect(response).to have_http_status(:ok)
      expect(group.reload.users).to contain_exactly(owner, member, outsider)
    end
  end

  describe "group memberships" do
    it "does not let an outsider join or list a group" do
      sign_in(outsider)

      post group_group_memberships_url(group), params: { group_membership: { user_id: outsider.id } }, as: :json
      expect(response).to have_http_status(:not_found)

      get group_group_memberships_url(group), as: :json
      expect(response).to have_http_status(:not_found)
      expect(group.reload.users).not_to include(outsider)
    end

    it "lists only this group's memberships" do
      create(:group, user: outsider, user_ids: [ outsider.id ])
      sign_in(member)

      get group_group_memberships_url(group), as: :json

      expect(Oj.load(response.body)["data"].map { |m| m["attributes"]["user_id"] }).to contain_exactly(owner.id, member.id)
    end

    it "lets a member add someone, and lets a past member rejoin" do
      group.group_memberships.find_by(user: member).update!(left_at: Date.current)
      sign_in(owner)

      post group_group_memberships_url(group), params: { group_membership: { user_id: member.id } }, as: :json

      expect(response).to have_http_status(:created)
      expect(group.reload.users).to include(member)
      expect(group.group_memberships.where(user: member).count).to eq(1)
    end

    it "lets a member leave but not remove others" do
      third = create(:user)
      group.group_memberships.create!(user: third)
      sign_in(member)

      delete group_group_membership_url(group, group.group_memberships.find_by(user: third)), as: :json
      expect(response).to have_http_status(:forbidden)

      delete group_group_membership_url(group, group.group_memberships.find_by(user: member)), as: :json
      expect(response).to have_http_status(:ok)
      expect(group.reload.users).not_to include(member)
    end
  end
end
