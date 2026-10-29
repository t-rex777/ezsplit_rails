class ExpensesController < ApplicationController
  class InvalidDistributionError < StandardError; end

  before_action :set_visible_expense, only: %i[show]
  before_action :set_expense, only: %i[update destroy]
  rescue_from InvalidDistributionError, with: :render_error

  def index
    pagy_obj, @expenses = pagy(filtered_expenses.includes(:category, :expenses_users, :payer, :group))
    Group.preload_for_serializer(@expenses.map(&:group))
    User.preload_for_serializer(@expenses.map(&:payer))
    options = {
      include: [ :payer, :group, :category, :expenses_users ]
    }
    render json: ExpenseSerializer.new(@expenses, options.merge(meta: pagy_metadata(pagy_obj))).serializable_hash.to_json
  end

  def show
    options = {
      include: [ :payer, :group, :category, :expenses_users ]
    }
    render json: ExpenseSerializer.new(@expense, options).serializable_hash.to_json
  end

  def create
    @expense = current_user.expenses.new(expense_params.except(:distribution))
    shares = build_shares(@expense.amount, @expense.split_type)
    raise InvalidDistributionError, "Distribution is required" if shares.nil?

    ActiveRecord::Base.transaction do
      @expense.validate!
      authorize_participants!(@expense, shares.keys)
      @expense.save!
      create_expenses_users(@expense, shares)
      record_activity("created", before: nil, after: @expense.snapshot)
    end
    render json: ExpenseSerializer.new(@expense).serializable_hash.to_json
  rescue ActiveRecord::RecordInvalid, InvalidDistributionError => exception
    render json: { errors: [ exception.message ] }, status: :unprocessable_entity
  end

  def update
    before = @expense.snapshot
    @expense.assign_attributes(expense_params.except(:distribution))
    shares = build_shares(@expense.amount, @expense.split_type)
    if shares.nil? && (@expense.amount_changed? || @expense.split_type_changed?)
      raise InvalidDistributionError, "Distribution is required when amount or split type changes"
    end

    ActiveRecord::Base.transaction do
      @expense.validate!
      authorize_participants!(@expense, shares ? shares.keys : @expense.expenses_users.pluck(:user_id))
      @expense.save!
      if shares
        @expense.expenses_users.destroy_all
        create_expenses_users(@expense, shares)
      end
      record_activity("updated", before: before, after: @expense.snapshot)
    end
    render json: ExpenseSerializer.new(@expense).serializable_hash.to_json
  rescue ActiveRecord::RecordInvalid, InvalidDistributionError => exception
    render json: { errors: [ exception.message ] }, status: :unprocessable_entity
  end

  def destroy
    ActiveRecord::Base.transaction do
      record_activity("deleted", before: @expense.snapshot, after: nil)
      @expense.destroy!
    end
    render json: { message: "Expense was successfully deleted" }, status: :ok
  rescue StandardError => e
    render json: { errors: [ e.message ] }, status: :unprocessable_entity
  end

  private

  def record_activity(action, before:, after:)
    Activity.record!(actor: current_user, action: action, expense_id: @expense.id, group_id: @expense.group_id,
                     before: before, after: after)
  end

  SORTS = {
    "newest" => { expense_date: :desc, id: :desc },
    "oldest" => { expense_date: :asc, id: :asc },
    "amount_desc" => { amount: :desc, id: :desc },
    "amount_asc" => { amount: :asc, id: :asc }
  }.freeze

  def filtered_expenses
    expenses = current_user.visible_expenses
    expenses = expenses.where(group_id: params[:group_id]) if params[:group_id].present?
    expenses = expenses.where("LOWER(expenses.name) LIKE ?", "%#{Expense.sanitize_sql_like(params[:q].downcase)}%") if params[:q].present?
    expenses = expenses.where(category_id: params[:category_ids]) if params[:category_ids].present?
    expenses = expenses.where(payer_id: current_user.id) if params[:paid_by] == "me"
    expenses = expenses.where.not(payer_id: current_user.id) if params[:paid_by] == "others"
    expenses = expenses.where(expense_date: params[:from]..) if params[:from].present?
    expenses = expenses.where(expense_date: ..params[:to]) if params[:to].present?
    expenses.order(SORTS.fetch(params[:sort], SORTS["newest"]))
  end

  def create_expenses_users(expense, shares)
    shares.each do |user_id, amount|
      expense.expenses_users.create!(user_id: user_id, amount: amount)
    end
  end

  # Returns { user_id => BigDecimal share }, or nil when no distribution was sent.
  def build_shares(amount, split_type)
    distribution = params.dig(:expense, :distribution)
    return nil if distribution.blank?

    entries = distribution.map { |entry| [ entry[:user_id].to_i, entry[:amount] ] }
    user_ids = entries.map(&:first)
    raise InvalidDistributionError, "Each person can appear only once in the distribution" if user_ids.uniq.size != user_ids.size

    unless Expense::SPLIT_TYPES.include?(split_type)
      raise InvalidDistributionError, "Split type must be equal, percentage or exact"
    end

    raise InvalidDistributionError, "Amount is required" if amount.blank?
    total = to_decimal(amount)
    raise InvalidDistributionError, "Amount must be greater than 0" unless total.positive?

    shares =
      case split_type
      when "equal"
        split_by_weights(total, user_ids.index_with { 1 })
      when "exact"
        exact = entries.to_h { |user_id, value| [ user_id, to_decimal(value) ] }
        raise InvalidDistributionError, "Amount must be equal to the sum of the distribution" if exact.values.sum != total
        exact
      when "percentage"
        percents = entries.to_h { |user_id, value| [ user_id, to_decimal(value) ] }
        raise InvalidDistributionError, "Total percentage must equal 100" if percents.values.sum != 100
        split_by_weights(total, percents)
      end

    raise InvalidDistributionError, "Shares cannot be negative" if shares.values.any?(&:negative?)
    shares
  end

  # Splits total by weight, rounded down to the cent. Leftover cents go one each to the first people,
  # so the shares always add up to the total exactly.
  def split_by_weights(total, weights)
    weight_sum = weights.values.sum
    shares = weights.transform_values { |weight| (total * weight / weight_sum).round(2, BigDecimal::ROUND_DOWN) }
    leftover_cents = ((total - shares.values.sum) * 100).to_i
    shares.keys.first(leftover_cents).each { |user_id| shares[user_id] += BigDecimal("0.01") }
    shares
  end

  def to_decimal(value)
    BigDecimal(value.to_s).round(2)
  rescue ArgumentError, TypeError
    raise InvalidDistributionError, "Amounts must be numbers"
  end

  # Group expenses: everyone must be an active member. Friend expenses: everyone must be you or a friend.
  def authorize_participants!(expense, participant_ids)
    raise InvalidDistributionError, "Category not found" unless current_user.categories.exists?(expense.category_id)

    people = participant_ids.map(&:to_i) | [ expense.payer_id ]

    if expense.group_id
      group = current_user.groups.find_by(id: expense.group_id)
      raise InvalidDistributionError, "Group not found" unless group

      outsiders = people - group.active_memberships.pluck(:user_id)
      raise InvalidDistributionError, "Everyone in the expense must be a member of the group" if outsiders.any?
    else
      outsiders = people - current_user.friend_ids_with_self
      raise InvalidDistributionError, "Everyone in the expense must be you or one of your friends" if outsiders.any?
    end
  end

  def expense_params
    params.require(:expense).permit(:name, :amount, :split_type, :currency, :expense_date, :settled, :payer_id, :group_id, :category_id, :notes, distribution: [ :user_id, :amount ])
  end

  # Only the creator can change or delete an expense.
  def set_expense
    @expense = current_user.expenses.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { errors: [ "Expense not found" ] }, status: :not_found
  end

  # The creator, the payer, and everyone in the split can view an expense.
  def set_visible_expense
    @expense = current_user.visible_expenses.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { errors: [ "Expense not found" ] }, status: :not_found
  end

  def render_error(exception)
    render json: { errors: [ exception.message ] }, status: :unprocessable_entity
  end
end
