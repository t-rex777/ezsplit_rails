class GroupsController < ApplicationController
  before_action :set_group, only: %i[ show edit update destroy add_members]

  # GET /groups
  def index
    pagy_obj, @groups = pagy(current_user.groups)
    options = {
      include: [ :users ]
    }
    render json: GroupSerializer.new(@groups, options.merge(meta: pagy_metadata(pagy_obj))).serializable_hash.to_json
  end

  # GET /groups/1
  def show
     render json: GroupSerializer.new(@group, include: [ :users ]).serializable_hash.to_json
  end

  # POST /groups
  def create
    @group = current_user.groups.new(group_params)

      if @group.save
          render json: GroupSerializer.new(@group).serializable_hash.to_json,
          status: :created
      else
          render json: {
            errors: @group.errors.full_messages
          }, status: :unprocessable_entity
      end
  end

  # PATCH/PUT /groups/1
  def update
      if @group.update(group_params)
        # Handle member updates
        if params[:group][:user_ids].present?
          update_members(params[:group][:user_ids])
        end
          render json: GroupSerializer.new(@group, include: [ :users ]).serializable_hash.to_json
      else
          render json: {
            errors: @group.errors.full_messages
          }, status: :unprocessable_entity
      end
  end

  # DELETE /groups/1
  def destroy
    if @group.destroy! do
        render json: { message: "Group was successfully deleted" }, status: :ok
      end
    else
      render json: {
        errors: @group.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # POST /groups/1/add_members
  def add_members
    user_ids = params[:group][:user_ids] || []

    begin
      update_members(user_ids)

      respond_to do |format|
        format.json do
          render json: GroupSerializer.new(@group, include: [ :users ]).serializable_hash.to_json
        end
      end
    rescue => e
      respond_to do |format|
        format.json do
          render json: {
            errors: [ e.message ]
          }, status: :unprocessable_entity
        end
      end
    end
  end

  private
    def set_group
      @group = current_user.groups.find(params.fetch(:id))
    rescue ActiveRecord::RecordNotFound
          render json: {
            errors: [ "Group not found" ]
          }, status: :not_found
    end

    def group_params
      params.require(:group).permit(:name, :description, user_ids: [])
    end

    def update_members(user_ids)
      ActiveRecord::Base.transaction do
         # Remove memberships which are not included
         @group.group_memberships.where.not(user_id: user_ids).destroy_all

        # Add new memberships
        user_ids.each do |user_id|
          next if @group.group_memberships.exists?(user_id: user_id)
          @group.group_memberships.create!(user_id: user_id)
        end
      end
    end
end
