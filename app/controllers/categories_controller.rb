class CategoriesController < ApplicationController
  before_action :set_category, only: %i[ show edit update destroy ]

  # GET /categories or /categories.json
  def index
    pagy_obj, categories = pagy(Category.all)
    render json: CategorySerializer.new(categories, meta: pagy_metadata(pagy_obj)).serializable_hash.to_json
  end

  # GET /categories/1 or /categories/1.json
  def show
    render json: CategorySerializer.new(@category).serializable_hash.to_json
  end

  # GET /categories/new
  def new
    @category = Category.new
  end

  # GET /categories/1/edit
  def edit
  end

  # POST /categories or /categories.json
  def create
    @category = Category.new(category_params)

    respond_to do |format|
      if @category.save
        format.json do
          render json: CategorySerializer.new(@category).serializable_hash.to_json,
                 status: :created
        end
      else
        format.json do
          render json: {
            errors: @category.errors.full_messages
          }, status: :unprocessable_entity
        end
      end
    end
  end

  # PATCH/PUT /categories/1 or /categories/1.json
  def update
    respond_to do |format|
      if @category.update(category_params)
        format.json do
          render json: CategorySerializer.new(@category).serializable_hash.to_json,
                 status: :ok
        end
      else
        format.json do
          render json: {
            errors: @category.errors.full_messages
          }, status: :unprocessable_entity
        end
      end
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
      @category = Category.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def category_params
      params.expect(category: [ :name, :icon, :color, :created_by_id ])
    end
end
