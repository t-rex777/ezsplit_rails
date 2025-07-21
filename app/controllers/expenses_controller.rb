class ExpensesController < ApplicationController
  before_action :set_expense, only: %i[ update ]

  def index
    pagy_obj, @expenses = pagy(Expense.all)
    options = {
      include: [ :payer, :group, :category ]
    }
    render json: ExpenseSerializer.new(@expenses, options.merge(meta: pagy_metadata(pagy_obj))).serializable_hash.to_json
  end


  def create
    @expense = Expense.new(expense_params)

    if @expense.save
      render json: ExpenseSerializer.new(@expense).serializable_hash.to_json
    else
      respond_to do |format|
        format.json do
          render json: { errors: @expense.errors.full_messages }, status: :unprocessable_entity
        end
      end
    end
  end

  def update
    if @expense.update(expense_params)
      render json: ExpenseSerializer.new(@expense).serializable_hash.to_json
    else
      respond_to do |format|
        format.json do
          render json: { errors: @expense.errors.full_messages }, status: :unprocessable_entity
        end
      end
    end
  end

  private
  def expense_params
    params.require(:expense).permit(:name, :amount, :split_type, :currency, :expense_date, :settled, :payer_id, :group_id, :category_id)
  end

  def set_expense
    @expense = Expense.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.json do
        render json: { errors: [ "Expense not found" ] }, status: :not_found
      end
    end
  end
end
