class InvitationsController < ApplicationController
  allow_unauthenticated_access only: %i[update]
  before_action :set_invitation, only: [ :update ]
  before_action :set_invited_user, only: [ :create, :update ]


  # if user present -> just create an invitation and add to friends list
  # if not present -> TBD

  # POST /invitations
  def create
    if @invited_user.present?
      if @invited_user.friends.include?(current_user)
        render json: { message: "#{@invited_user.full_name} is already a friend." }
        return
      end

      ActiveRecord::Base.transaction do
        invitation_params = {
          email: create_invitation_params[:email_address],
          inviter: current_user,
          invited_user: @invited_user,
          status: :accepted,
          accepted_at: Time.now
        }

        @invitation = current_user.invitations.new(invitation_params)
        @invitation.invited_user.friendships.create!(friend: @invitation.inviter)
        @invitation.inviter.friendships.create!(friend: @invitation.invited_user)
      end

      if @invitation.save
        render json: { message: "#{@invited_user.full_name} added as friend." }, status: :created
        return
      end
    end

    @invitation = current_user.invitations.new(
      email: create_invitation_params[:email_address],
      inviter: current_user
    )

    if @invitation.save
      # Send invitation email
      UserMailer.invitation_email(@invitation).deliver_now
      render json: { message: "Invitation sent successfully." }, status: :created
    else
      render json: { errors: @invitation.errors.full_messages }, status: :unprocessable_entity
    end
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

  def create_invitation_params
    params.require(:invitation).permit(:email_address, :message)
  end

  def update_invitation_params
    params.require(:invitation).permit(:token, :email_address)
  end
end
