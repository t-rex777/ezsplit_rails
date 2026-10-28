class MeController < ApplicationController
  # GET /me
  def show
    render json: UserSerializer.new(current_user).serializable_hash.to_json
  end

  # PATCH /me
  # Email is the login, so it can't be changed here.
  def update
    if current_user.update(me_params)
      render json: UserSerializer.new(current_user).serializable_hash.to_json
    else
      render json: { errors: current_user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def me_params
    params.require(:user).permit(:first_name, :last_name, :phone, :date_of_birth)
  end
end
