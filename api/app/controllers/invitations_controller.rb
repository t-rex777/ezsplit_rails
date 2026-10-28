class InvitationsController < ApplicationController
  allow_unauthenticated_access only: %i[update]
  before_action :set_invitation, only: [ :update ]
  before_action :set_received_invitation, only: %i[ accept decline ]
  before_action :set_invited_user, only: [ :create, :update ]

  # GET /invitations
  # Friend requests waiting for me, newest first.
  def index
    invitations = Invitation.pending.where("expires_at > ?", Time.current)
                            .where(invited_user_id: current_user.id)
                            .or(Invitation.pending.where("expires_at > ?", Time.current)
                                          .where("lower(email) = ?", current_user.email_address.downcase))
                            .includes(:inviter).order(created_at: :desc, id: :desc)

    render json: { data: invitations.map { |invitation| invitation_json(invitation) } }
  end

  # POST /invitations
  # An existing user gets a friend request to accept; the reply is the same as for a new user,
  # so it never reveals whether an account exists.
  def create
    if @invited_user&.friends&.include?(current_user)
      render json: { message: "#{@invited_user.full_name} is already a friend." }
      return
    end

    email = create_invitation_params[:email_address]
    if @invited_user.present? && pending_invitation_to?(email)
      render json: { message: "Invitation sent successfully." }, status: :created
      return
    end

    @invitation = current_user.invitations.new(email: email, invited_user: @invited_user)

    if @invitation.save
      if @invited_user.present?
        UserMailer.friend_request_email(@invitation).deliver_now
      else
        UserMailer.invitation_email(@invitation).deliver_now
      end
      render json: { message: "Invitation sent successfully." }, status: :created
    else
      render json: { errors: @invitation.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # POST /invitations/:id/accept
  def accept
    ActiveRecord::Base.transaction do
      Friendship.find_or_create_by!(user: current_user, friend: @invitation.inviter)
      Friendship.find_or_create_by!(user: @invitation.inviter, friend: current_user)
      @invitation.update!(invited_user: current_user, status: :accepted, accepted_at: Time.current)
    end

    render json: { message: "You are now friends with #{@invitation.inviter.full_name}." }
  end

  # POST /invitations/:id/decline
  def decline
    @invitation.update!(invited_user: current_user, status: :rejected)
    render json: { message: "Invitation declined." }
  end

  # PUT /invitations/:id
  def update
    if @invited_user.nil?
      render json: { message: "User not found. Please create a new account." }, status: :not_found
      return
    end

    begin
      service = InvitationAcceptanceService.new(@invitation, @invited_user, update_invitation_params[:token])
      result = service.call

      if result[:success]
        render json: { message: result[:message] }, status: :ok
      elsif result[:error] == "Invitation not found."
        render json: { message: result[:error] }, status: :not_found
      else
        render json: { message: result[:error] }, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordInvalid => e
      render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_invited_user
    @invited_user = User.find_by_email_address(update_invitation_params[:email_address])
  end

  def set_invitation
    @invitation = Invitation.find_by(id: params[:id])
  end

  def set_received_invitation
    @invitation = Invitation.find_by(id: params[:id])

    unless @invitation && (@invitation.invited_user_id == current_user.id || @invitation.sent_to?(current_user))
      render json: { errors: [ "Invitation not found." ] }, status: :not_found
      return
    end

    return if @invitation.pending? && !@invitation.expired?

    render json: { errors: [ "This invitation is no longer valid." ] }, status: :unprocessable_entity
  end

  def pending_invitation_to?(email)
    current_user.invitations.pending.where("expires_at > ?", Time.current)
                .exists?([ "lower(email) = ?", email.to_s.strip.downcase ])
  end

  def invitation_json(invitation)
    inviter = invitation.inviter
    {
      id: invitation.id,
      created_at: invitation.created_at,
      inviter: inviter.slice(:id, :first_name, :last_name, :email_address)
    }
  end

  def create_invitation_params
    params.require(:invitation).permit(:email_address, :message)
  end

  def update_invitation_params
    params.require(:invitation).permit(:token, :email_address)
  end
end
