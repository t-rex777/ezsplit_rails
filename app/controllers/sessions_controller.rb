class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> {
    respond_to do |format|
      format.json do
        render json: {
          status: :error,
          errors: [ "Rate limit exceeded" ],
          message: "Too many login attempts. Try again later."
        }, status: :too_many_requests
      end
      format.html { redirect_to new_session_url, alert: "Try again later." }
    end
  }

  def show
    session = find_session_by_cookie
    options = {
      include: [ :groups ]
    }
    render json: UserSerializer.new(session.user, options).serializable_hash.to_json
  end

  def new
  end

  def create
    permitted_params = params.permit(:email_address, :password)
    Rails.logger.info "Login attempt with: #{permitted_params.inspect}"

    user = User.find_by(email_address: permitted_params[:email_address])
    Rails.logger.info "User found: #{user&.email_address || 'No user found'}"

    respond_to do |format|
      if user = User.authenticate_by(permitted_params)
        Rails.logger.info "Authentication successful: #{user.email_address}"
        session = start_new_session_for(user)

        format.json do
          render json: {
            status: :success,
            data: {
              user: UserSerializer.new(user).serializable_hash,
              session: {
                id: session.id,
                created_at: session.created_at
              }
            },
            message: "Signed in successfully"
          }
        end
        format.html { redirect_to after_authentication_url, notice: "Signed in successfully" }
      else
        Rails.logger.info "Authentication failed"
        format.json do
          render json: {
            status: :error,
            errors: [ "Invalid credentials" ],
            message: "Invalid email address or password"
          }, status: :unauthorized
        end
        format.html { redirect_to new_session_path, alert: "Try another email address or password." }
      end
    end
  end

  def destroy
    respond_to do |format|
      terminate_session
      format.json do
        render json: {
          status: :success,
          message: "Signed out successfully"
        }
      end
      format.html { redirect_to new_session_path }
    end
  end

  private

  def find_session_by_cookie
     Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
  end
end
