require "rails_helper"

RSpec.describe "Groups", type: :request do
  let!(:user1) { create(:user, email_address: "test1@example.com") }
  let!(:user2) { create(:user, email_address: "test2@example.com") }

  before do
    post session_url, params: { email_address: user1.email_address, password: user1.password }
  end

  describe "PUT /groups/:id" do
    let(:group_params) do
      {
        name: "Test Group",
        description: "Fun group",
        created_by_id: user1.id,
        user_ids: []
      }
    end

    let!(:group) { Group.create!(group_params.merge(user_ids: [ user1.id ])) } # Initialize with user1
    let!(:group2) { Group.create!(group_params.merge(user_ids: [ user1.id ])) }

    context "with valid params" do
      it "updates the group with more users" do
        put group_url(group), params: {
          group: group_params.merge(user_ids: [ user1.id, user2.id ])
        }

        expect(response).to have_http_status(:found)
        expect(response).to redirect_to(group_path(group))

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

        expect(response).to have_http_status(:found)
        expect(response).to redirect_to(group_path(group))

        # Verify that user1 was removed and user2 was added
        group.reload
        expect(group.users).to include(user2)
        expect(group.users).not_to include(user1)

        expect(GroupMembership.find_by(user_id: user1.id, group_id: group.id)).to be_nil
      end
    end
  end
end
