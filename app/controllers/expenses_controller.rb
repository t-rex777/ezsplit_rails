class ExpensesController < ApplicationController
  class InvalidDistributionError < StandardError; end

  before_action :set_expense, only: %i[update destroy show]
  before_action :validate_expense_split, only: %i[create update]
  rescue_from InvalidDistributionError, with: :render_error

  def index
    pagy_obj, @expenses = pagy(Expense.all)
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
    ActiveRecord::Base.transaction do
      @expense = Expense.create!(expense_params.except(:distribution))
      create_expenses_users(@expense)
    end
    render json: ExpenseSerializer.new(@expense).serializable_hash.to_json
  rescue ActiveRecord::RecordInvalid, InvalidDistributionError => exception
    render json: { errors: [ exception.message ] }, status: :unprocessable_entity
  end

  def update
    ActiveRecord::Base.transaction do
      destroy_expense_users(@expense)
     @expense.update!(expense_params.except(:distribution))
      create_expenses_users(@expense)
    end
      render json: ExpenseSerializer.new(@expense).serializable_hash.to_json
  rescue ActiveRecord::RecordInvalid, InvalidDistributionError => exception
      render json: { errors: [ exception.message ] }, status: :unprocessable_entity
  end

  def destroy
    @expense.destroy!
    render json: { message: "Expense was successfully deleted" }, status: :ok
  rescue StandardError => e
    render json: { errors: [ e.message ] }, status: :unprocessable_entity
  end

  private

  def create_expenses_users(expense)
    params[:expense][:distribution].map do |user|
      amount = params[:expense][:split_type] == "percentage" ? user[:amount].to_f * params[:expense][:amount].to_f / 100 : user[:amount].to_f

      expense_user = ExpensesUser.create!(
        user_id: user[:user_id],
        expense_id: expense.id,
        amount: amount
      )
    end
  end

  def destroy_expense_users(expense)
    expense.expenses_users.destroy_all
  end

  def validate_expense_split
    return unless params[:expense][:distribution].present?

    total_amount = params[:expense][:distribution].map { |user| user[:amount].to_f }.sum

    case params[:expense][:split_type]
    when "equal", "exact"
      if total_amount.to_f != params[:expense][:amount].to_f
        message = "Amount must be equal to the sum of the distribution"
        raise InvalidDistributionError, message
      end
    when "percentage"
      if total_amount.round(2) != 100.0
        message = "Total percentage must equal 100"
        raise InvalidDistributionError, message
      end
    else
      message = "Split type must be equal, percentage or exact"
      raise InvalidDistributionError, message
    end
  end

  # TODO: if amount is changed, distribution should also be changed
  def expense_params
    params.require(:expense).permit(:name, :amount, :split_type, :currency, :expense_date, :settled, :payer_id, :group_id, :category_id, distribution: [ :user_id, :amount ])
  end

  def set_expense
    @expense = Expense.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { errors: [ "Expense not found" ] }, status: :not_found
  end

  def render_error(exception)
    render json: { errors: [ exception.message ] }, status: :unprocessable_entity
  end
end
