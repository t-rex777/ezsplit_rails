class UsersController < ApplicationController
  # GET /users
  def index
    pagy_obj, @users = pagy(current_user.friends)
    preload_for_serializer(@users)
    options = {
      include: [ :groups ],
      fields: { user: UserSerializer::PUBLIC_FIELDS }
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
    preload_for_serializer(@users)

    options = {
      include: [ :groups ],
      fields: { user: UserSerializer::PUBLIC_FIELDS }
    }

    render json: UserSerializer.new(@users, options.merge(meta: pagy_metadata(pagy_obj))).serializable_hash.to_json
  end


  private

  def preload_for_serializer(users)
    User.preload_for_serializer(users)
    Group.preload_for_serializer(users.flat_map(&:groups))
  end

  def user_params
    params.require(:user).permit(:email_address, :first_name, :last_name)
  end
end
