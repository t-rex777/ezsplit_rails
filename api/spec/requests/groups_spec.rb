require "rails_helper"

RSpec.describe "Groups", type: :request do
  let!(:user1) { create(:user, email_address: "test1@example.com") }
  let!(:user2) { create(:user, email_address: "test2@example.com") }
  let!(:user3) { create(:user, email_address: "test3@example.com") }
  let!(:user4) { create(:user, email_address: "test4@example.com") }

  before do
    create(:friendship, user: user1, friend: user2)
    post session_url, params: { email_address: user1.email_address, password: user1.password }
  end

  describe "GET /groups" do
      before do
        create(:group, name: "Test Group", description: "Fun group", user_id: user1.id, user_ids: [ user1.id, user2.id ])
        create(:group, name: "Test Group 2", description: "Fun group 2", user_id: user2.id, user_ids: [ user2.id, user4.id ])
        create(:group, name: "Test Group 3", description: "Fun group 3", user_id: user1.id, user_ids: [ user1.id, user3.id ])
      end

    it "returns a list of groups" do
      get groups_url

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Test Group")
      expect(response.body).to_not include("Test Group 2")
      expect(response.body).to include("Test Group 3")
    end
  end

  describe "GET /groups/:id" do
    let!(:group) { create(:group, name: "Test Group", description: "Fun group", user_id: user1.id, user_ids: [ user1.id, user2.id ]) }

    it "returns a group" do
      get group_url(group)

      response_body = Oj.load(response.body)
      expect(response).to have_http_status(:ok)
      expect(response_body.fetch("data").fetch("attributes")).to eq({
        name: "Test Group",
        description: "Fun group",
        expense_summary: {
          total_expenses: 0,
          total_amount: "0.0",
          current_user_balance: { total_paid: "0.0", total_owed: "0.0", net_balance: "0.0", status: "owes" },
          currency: nil
        },
        owner_id: user1.id,
        my_net: "0.0",
        last_activity_at: Group.last.last_activity_at.as_json
        }.with_indifferent_access)
    end
  end

  describe "POST /groups" do
    it "creates a group with the given parameters" do
      post groups_url, params: {
        group: {
          name: "Test Group",
          description: "Fun group",
          user_ids: [ user1.id, user2.id ]
        }
      }

      response_body = Oj.load(response.body)
      expect(response).to have_http_status(:created)

      expect(response_body.fetch("data").fetch("attributes")).to eq({
        name: "Test Group",
        description: "Fun group",
        expense_summary: {
          total_expenses: 0,
          total_amount: "0.0",
          current_user_balance: { total_paid: "0.0", total_owed: "0.0", net_balance: "0.0", status: "owes" },
          currency: nil
        },
        owner_id: user1.id,
        my_net: "0.0",
        last_activity_at: Group.last.last_activity_at.as_json
        }.with_indifferent_access)
    end
  end

  describe "PUT /groups/:id" do
    let(:group_params) do
      {
        name: "Test Group",
        description: "Fun group",
        user_ids: []
      }
    end

    let!(:group) { Group.create!(group_params.merge(user_ids: [ user1.id ], user_id: user1.id)) } # Initialize with user1
    let!(:group2) { Group.create!(group_params.merge(user_ids: [ user1.id ], user_id: user1.id)) }
    let!(:group3) { Group.create!(group_params.merge(user_ids: [ user3.id ], user_id: user3.id)) }


    context "with valid params" do
      it "updates the group with more users" do
        put group_url(group), params: {
          group: group_params.merge(user_ids: [ user1.id, user2.id ])
        }

        expect(response).to have_http_status(:ok)

        # Verify that the users were actually added
        group.reload
        expect(group.users).to include(user1, user2)
      end

      it "updates the group when users are removed" do
        # Verify user1 is initially in the group
        expect(group.users).to include(user1)

        put group_url(group), params: {
          group: group_params.merge(user_ids: [ user2.id ])
        }

        expect(response).to have_http_status(:ok)

        # Verify that user1 was removed and user2 was added
        group.reload
        expect(group.users).to include(user2)
        expect(group.users).not_to include(user1)

        # Leaving keeps the row so past expenses keep their history.
        expect(GroupMembership.find_by(user_id: user1.id, group_id: group.id).left_at).to eq(Date.current)
      end
    end

    it "returns an error when the group does not exist" do
      put group_url(group3), params: {
        group: group_params.merge(user_ids: [ user3.id ])
      }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /groups/:id" do
    let!(:group) { Group.create!({ name: "Awesome Group", user_ids: [ user1.id ], user_id: user1.id }) }
    let!(:group2) { Group.create!({ name: "Black panther", user_ids: [ user2.id ], user_id: user2.id }) }


    it "deletes the group" do
      delete group_url(group)
      expect(response).to have_http_status(:ok)
      expect(Oj.load(response.body)["message"]).to eq("Group was successfully deleted")
      expect(Group.exists?(group.id)).to be false
    end

    it "returns an error when the group does not exist" do
      delete group_url(group2)

      expect(response).to have_http_status(:not_found)
    end
  end
end
