class UsersController < ApplicationController
  # GET /users
  def index
    pagy_obj, @users = pagy(current_user.friends)
    options = {
      include: [ :groups ]
    }
    render json: UserSerializer.new(@users, options.merge(meta: pagy_metadata(pagy_obj))).serializable_hash.to_json
  end

  # GET /users/search
  def search
    query = params[:term]&.strip
    per_page = (params[:limit] || 5).to_i

    if query.blank?
      render json: {
        status: :error,
        message: "Search query is required",
        errors: [ "Query parameter 'term' is required" ]
      }, status: :unprocessable_entity
      return
    end

    # Search in email_address, first_name, and last_name
    @users = current_user.friends.where(
      "email_address LIKE :query OR first_name LIKE :query OR last_name LIKE :query",
      query: "%#{query}%"
    )

    # Apply pagination
    pagy_obj, @users = pagy(@users, limit: per_page)

    options = {
      include: [ :groups ]
    }

    render json: UserSerializer.new(@users, options.merge(meta: pagy_metadata(pagy_obj))).serializable_hash.to_json
  end


  private

  def user_params
    params.require(:user).permit(:email_address, :first_name, :last_name)
  end
end
