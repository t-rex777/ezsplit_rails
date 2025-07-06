class GroupMembershipsController < ApplicationController
  def new
    @group_membership = GroupMembership.new
  end

  def create
    @group_membership = GroupMembership.new(group_membership_params)

    if @group_membership.save
      redirect_to @group_membership.group, notice: "You have joined the group"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @group_membership = GroupMembership.find(params.expect(:id))
    @group_membership.update!(left_at: Date.current)
    redirect_to @group_membership.group, notice: "You have left the group"
  end

  private
    def group_membership_params
      params.expect(group_membership: [ :user_id, :group_id ])
    end
end
