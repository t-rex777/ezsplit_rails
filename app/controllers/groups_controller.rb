class GroupsController < ApplicationController
  before_action :set_group, only: %i[ show edit update destroy add_members]

  # GET /groups or /groups.json
  def index
    @groups = Group.all
  end

  # GET /groups/1 or /groups/1.json
  def show
  end

  # GET /groups/new
  def new
    @group = Group.new
  end

  # GET /groups/1/edit
  def edit
  end

  # POST /groups or /groups.json
  def create
    @group = Group.new(group_params)

    respond_to do |format|
      if @group.save
        format.html { redirect_to @group, notice: "Group was successfully created." }
        format.json { render :show, status: :created, location: @group }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @group.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /groups/1 or /groups/1.json
  def update
    respond_to do |format|
      if @group.update(group_params)
        # Handle member updates
        if params[:group][:user_ids].present?
          update_members(params[:group][:user_ids])
        end

        format.html { redirect_to @group, notice: "Group was successfully updated." }
        format.json { render :show, status: :ok, location: @group }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @group.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /groups/1 or /groups/1.json
  def destroy
    @group.destroy!

    respond_to do |format|
      format.html { redirect_to groups_path, status: :see_other, notice: "Group was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  # POST /groups/1/add_members
  def add_members
    user_ids = params[:group][:user_ids] || []
    update_members(user_ids)

    respond_to do |format|
      format.json { render :show, status: :ok, location: @group }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_group
      @group = Group.find(params.fetch(:id))
    end

    # Only allow a list of trusted parameters through.
    def group_params
      params.require(:group).permit(:name, :description, :created_by_id, user_ids: [])
    end

    # Update group memberships
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
