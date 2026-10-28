class CategoriesController < ApplicationController
  before_action :set_category, only: %i[ show edit update destroy ]

  # GET /categories or /categories.json
  def index
    pagy_obj, categories = pagy(current_user.categories)
    render json: CategorySerializer.new(categories, meta: pagy_metadata(pagy_obj)).serializable_hash.to_json
  end

  # GET /categories/1 or /categories/1.json
  def show
    render json: CategorySerializer.new(@category).serializable_hash.to_json
  end

  # POST /categories or /categories.json
  def create
    @category = current_user.categories.new(category_params)

    if @category.save
      render json: CategorySerializer.new(@category).serializable_hash.to_json
    else
      render json: {
        errors: @category.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /categories/1 or /categories/1.json
  def update
      if @category.update(category_params)
          render json: CategorySerializer.new(@category).serializable_hash.to_json
      else
          render json: {
            errors: @category.errors.full_messages
          }, status: :unprocessable_entity
      end
  end

  # DELETE /categories/1 or /categories/1.json
  def destroy
    @category.destroy!

    respond_to do |format|
      format.json do
        render json: {
          message: "Category was successfully destroyed."
        }, status: :ok
      end
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_category
      @category = current_user.categories.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def category_params
      params.require(:category).permit(:name, :icon, :color)
    end
end
