class GroupMembershipsController < ApplicationController
  before_action :find_group, only: %i[show destroy]

  def new
    @group_membership = GroupMembership.new
  end

  def show
    render json: GroupMembershipSerializer.new(@group_membership).serializable_hash.to_json
  end

  def index
    pagy_obj, group_memberships = pagy(GroupMembership.all)
    options = {
      include: [ :user, :group ]
    }
    render json: GroupMembershipSerializer.new(group_memberships, options.merge(meta: pagy_metadata(pagy_obj))).serializable_hash.to_json
  end

  def create
    @group_membership = GroupMembership.new(group_membership_params)

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
    respond_to do |format|
      if @group_membership.update(left_at: Date.current)
        format.json do
          render json: {
            status: :success,
            data: {
              group: @group_membership.group.as_json(
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
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.json do
        render json: {
          status: :error,
          errors: [ "Group membership not found" ],
          message: "Group membership with ID #{params[:id]} does not exist"
        }, status: :not_found
      end
      format.html { redirect_to groups_path, alert: "Group membership not found" }
    end
  end

  private

  def group_membership_params
    params.require(:group_membership).permit(:user_id, :group_id)
  end

  def find_group
    @group_membership = GroupMembership.find(params[:id])
  end
end
