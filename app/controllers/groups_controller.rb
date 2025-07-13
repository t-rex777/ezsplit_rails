class GroupsController < ApplicationController
  before_action :set_group, only: %i[ show edit update destroy add_members]

  # GET /groups
  def index
    @groups = Group.all

    respond_to do |format|
      format.json do
        render json: {
          status: :success,
          data: {
            items: @groups,
            total_count: @groups.count
          },
          message: "Groups retrieved successfully"
        }
      end
      format.html
    end
  end

  # GET /groups/1
  def show
    respond_to do |format|
      format.json do
        render json: {
          status: :success,
          data: {
            group: @group.as_json(include: { users: { only: [ :id, :email_address, :first_name, :last_name ] } })
          },
          message: "Group retrieved successfully"
        }
      end
      format.html
    end
  end

  # GET /groups/new
  def new
    @group = Group.new
  end

  # GET /groups/1/edit
  def edit
  end

  # POST /groups
  def create
    @group = Group.new(group_params)

    respond_to do |format|
      if @group.save
        format.json do
          render json: {
            status: :success,
            data: { group: @group },
            message: "Group was successfully created"
          }, status: :created
        end
        format.html { redirect_to @group, notice: "Group was successfully created." }
      else
        format.json do
          render json: {
            status: :error,
            errors: @group.errors.full_messages,
            message: "Failed to create group"
          }, status: :unprocessable_entity
        end
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /groups/1
  def update
    respond_to do |format|
      if @group.update(group_params)
        # Handle member updates
        if params[:group][:user_ids].present?
          update_members(params[:group][:user_ids])
        end

        format.json do
          render json: {
            status: :success,
            data: {
              group: @group.as_json(include: { users: { only: [ :id, :email_address, :first_name, :last_name ] } })
            },
            message: "Group was successfully updated"
          }
        end
        format.html { redirect_to @group, notice: "Group was successfully updated." }
      else
        format.json do
          render json: {
            status: :error,
            errors: @group.errors.full_messages,
            message: "Failed to update group"
          }, status: :unprocessable_entity
        end
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /groups/1
  def destroy
    @group.destroy!

    respond_to do |format|
      format.json do
        render json: {
          status: :success,
          message: "Group was successfully deleted"
        }, status: :ok
      end
      format.html { redirect_to groups_path, status: :see_other, notice: "Group was successfully destroyed." }
    end
  end

  # POST /groups/1/add_members
  def add_members
    user_ids = params[:group][:user_ids] || []

    begin
      update_members(user_ids)

      respond_to do |format|
        format.json do
          render json: {
            status: :success,
            data: {
              group: @group.as_json(include: { users: { only: [ :id, :email_address, :first_name, :last_name ] } })
            },
            message: "Members were successfully updated"
          }
        end
      end
    rescue => e
      respond_to do |format|
        format.json do
          render json: {
            status: :error,
            errors: [ e.message ],
            message: "Failed to update members"
          }, status: :unprocessable_entity
        end
      end
    end
  end

  private
    def set_group
      @group = Group.find(params.fetch(:id))
    rescue ActiveRecord::RecordNotFound
      respond_to do |format|
        format.json do
          render json: {
            status: :error,
            errors: [ "Group not found" ],
            message: "Group with ID #{params[:id]} does not exist"
          }, status: :not_found
        end
        format.html { redirect_to groups_path, alert: "Group not found" }
      end
    end

    def group_params
      params.require(:group).permit(:name, :description, :created_by_id, user_ids: [])
    end

    def update_members(user_ids)
      ActiveRecord::Base.transaction do
        # Remove existing memberships not in the new list
        @group.group_memberships.where.not(user_id: user_ids).destroy_all

        # Add new memberships
        user_ids.each do |user_id|
          next if @group.group_memberships.exists?(user_id: user_id)
          @group.group_memberships.create!(user_id: user_id)
        end
      end
    end
end
