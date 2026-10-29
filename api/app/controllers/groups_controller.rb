class GroupsController < ApplicationController
  before_action :set_group, only: %i[ show totals ]
  before_action :set_owned_group, only: %i[ update destroy add_members ]
  before_action :require_friend_members, only: %i[ create update add_members ]

  # GET /groups
  def index
    pagy_obj, @groups = pagy(current_user.groups.select("groups.*", "#{Group::ACTIVITY_SQL} AS activity_at").order("activity_at DESC", id: :desc))
    Group.preload_for_serializer(@groups)
    User.preload_for_serializer(@groups.flat_map(&:users))
    options = {
      include: [ :users ]
    }
    render json: GroupSerializer.new(@groups, options.merge(meta: pagy_metadata(pagy_obj))).serializable_hash.to_json
  end

  # GET /groups/1
  def show
     render json: GroupSerializer.new(@group, include: [ :users ]).serializable_hash.to_json
  end

  # GET /groups/1/totals
  # INR totals for the whole group: spent, my share, what I paid, by category, and by payer.
  def totals
    expenses = @group.expenses.where(currency: SummariesController::CURRENCY)
    my_share = ExpensesUser.where(expense_id: expenses.select(:id), user_id: current_user.id).sum(:amount)
    paid = expenses.group(:payer_id).sum(:amount).sort_by { |payer_id, amount| [ -amount, payer_id ] }
    payers = User.where(id: paid.map(&:first)).index_by(&:id)

    render json: {
      total_spent: expenses.sum(:amount).to_d.to_s("F"),
      my_share: my_share.to_d.to_s("F"),
      i_paid: expenses.where(payer_id: current_user.id).sum(:amount).to_d.to_s("F"),
      categories: SpendingByCategory.rows(expenses.pluck(:category_id, :amount), current_user),
      paid_by: paid.map do |payer_id, amount|
        payer = payers[payer_id]
        { user_id: payer_id, first_name: payer.first_name, last_name: payer.last_name, amount: amount.to_d.to_s("F") }
      end
    }
  end

  # POST /groups
  def create
    @group = current_user.owned_groups.new(group_params)

      if @group.save
          @group.group_memberships.find_or_create_by!(user_id: current_user.id)
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
      if @group.update(group_params.except(:user_ids))
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
    if @group.destroy
      render json: { message: "Group was successfully deleted" }, status: :ok
    else
      render json: {
        errors: @group.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # POST /groups/1/add_members
  def add_members
    user_ids = params[:group][:user_ids] || []

    update_members(user_ids)
    render json: GroupSerializer.new(@group, include: [ :users ]).serializable_hash.to_json
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: [ e.message ] }, status: :unprocessable_entity
  end

  private
    def set_group
      @group = current_user.groups.find(params.fetch(:id))
    rescue ActiveRecord::RecordNotFound
      render_group_not_found
    end

    def set_owned_group
      @group = current_user.owned_groups.find(params.fetch(:id))
    rescue ActiveRecord::RecordNotFound
      render_group_not_found
    end

    def render_group_not_found
      render json: {
        errors: [ "Group not found" ]
      }, status: :not_found
    end

    def require_friend_members
      user_ids = params.dig(:group, :user_ids)
      render_friends_only_error if user_ids.present? && !only_friends?(user_ids, @group)
    end

    def group_params
      params.require(:group).permit(:name, :description, user_ids: [])
    end

    def update_members(user_ids)
      user_ids = user_ids.map(&:to_i)

      ActiveRecord::Base.transaction do
        # Members who are not in the list leave the group. Their rows stay so past expenses keep their history.
        @group.group_memberships.active.where.not(user_id: user_ids).update_all(left_at: Date.current)

        user_ids.each do |user_id|
          membership = @group.group_memberships.find_or_initialize_by(user_id: user_id)
          membership.update!(left_at: nil)
        end
      end
    end
end
