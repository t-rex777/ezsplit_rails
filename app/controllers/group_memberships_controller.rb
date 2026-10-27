class GroupMembershipsController < ApplicationController
  before_action :set_group
  before_action :set_group_membership, only: %i[show destroy]

  def new
    @group_membership = @group.group_memberships.new
  end

  def show
    render json: GroupMembershipSerializer.new(@group_membership).serializable_hash.to_json
  end

  def index
    pagy_obj, group_memberships = pagy(@group.group_memberships)
    options = {
      include: [ :user, :group ]
    }
    render json: GroupMembershipSerializer.new(group_memberships, options.merge(meta: pagy_metadata(pagy_obj))).serializable_hash.to_json
  end

  def create
    @group_membership = @group.group_memberships.find_or_initialize_by(user_id: group_membership_params[:user_id])
    @group_membership.left_at = nil

    respond_to do |format|
      if @group_membership.save
        format.json do
          render json: {
            status: :success,
            data: {
              group_membership: @group_membership,
              group: @group_membership.group.as_json(
                include: {
                  users: {
                    only: [ :id, :email_address, :first_name, :last_name ]
                  }
                }
              )
            },
            message: "Successfully joined the group"
          }, status: :created
        end
        format.html { redirect_to @group_membership.group, notice: "You have joined the group" }
      else
        format.json do
          render json: {
            status: :error,
            errors: @group_membership.errors.full_messages,
            message: "Failed to join group"
          }, status: :unprocessable_entity
        end
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    unless @group_membership.user_id == current_user.id || @group.owner?(current_user)
      render json: {
        status: :error,
        errors: [ "Only the group owner can remove other members" ],
        message: "Failed to leave group"
      }, status: :forbidden
      return
    end

    leave_error = leave_error_for(@group_membership)
    if leave_error
      render json: { status: :error, errors: [ leave_error ], message: "Failed to leave group" }, status: :unprocessable_entity
      return
    end

    respond_to do |format|
      if @group_membership.update(left_at: Date.current)
        format.json do
          render json: {
            status: :success,
            data: {
              group: @group_membership.group.reload.as_json(
                include: {
                  users: {
                    only: [ :id, :email_address, :first_name, :last_name ]
                  }
                }
              )
            },
            message: "Successfully left the group"
          }
        end
        format.html { redirect_to @group_membership.group, notice: "You have left the group" }
      else
        format.json do
          render json: {
            status: :error,
            errors: @group_membership.errors.full_messages,
            message: "Failed to leave group"
          }, status: :unprocessable_entity
        end
        format.html { redirect_to @group_membership.group, alert: "Failed to leave group" }
      end
    end
  end

  private

  # Leaving with money still open would hide a debt, and a group always needs its owner.
  def leave_error_for(membership)
    return "The owner can't leave. Delete the group instead." if @group.user_id == membership.user_id

    open_balance = BalanceCalculator.for_group(@group).any? { |(user_id, _currency), amount| user_id == membership.user_id && !amount.zero? }
    "Settle up before leaving" if open_balance
  end

  def group_membership_params
    params.require(:group_membership).permit(:user_id)
  end

  # Only active members can see or change a group's memberships.
  def set_group
    @group = current_user.groups.find(params[:group_id])
  rescue ActiveRecord::RecordNotFound
    render_not_found("Group not found", "Group with ID #{params[:group_id]} does not exist")
  end

  def set_group_membership
    @group_membership = @group.group_memberships.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_not_found("Group membership not found", "Group membership with ID #{params[:id]} does not exist")
  end

  def render_not_found(error, message)
    respond_to do |format|
      format.json do
        render json: { status: :error, errors: [ error ], message: message }, status: :not_found
      end
      format.html { redirect_to groups_path, alert: error }
    end
  end
end
