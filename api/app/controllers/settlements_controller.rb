class SettlementsController < ApplicationController
  # GET /settlements
  def index
    settlements = Settlement.involving(current_user).order(settled_on: :desc, id: :desc)
    settlements = settlements.where(group_id: params[:group_id]) if params[:group_id].present?
    pagy_obj, settlements = pagy(settlements)
    render json: SettlementSerializer.new(settlements, meta: pagy_metadata(pagy_obj)).serializable_hash.to_json
  end

  # POST /settlements
  # The current user records that they paid `payee_id` back.
  def create
    settlement = current_user.settlements_paid.new(settlement_params)

    error = participant_error(settlement)
    if error
      render json: { errors: [ error ] }, status: :unprocessable_entity
    elsif save_with_activity(settlement)
      render json: SettlementSerializer.new(settlement).serializable_hash.to_json, status: :created
    else
      render json: { errors: settlement.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /settlements/1
  def destroy
    settlement = current_user.settlements_paid.find_by(id: params[:id])
    if settlement.nil?
      render json: { errors: [ "Settlement not found" ] }, status: :not_found
      return
    end

    settlement.destroy!
    render json: { message: "Settlement was successfully deleted" }, status: :ok
  end

  private

  def save_with_activity(settlement)
    Settlement.transaction do
      next false unless settlement.save

      Activity.record!(actor: current_user, action: "settled", settlement_id: settlement.id,
                       group_id: settlement.group_id, before: nil, after: settlement.snapshot)
      true
    end
  end

  def settlement_params
    params.require(:settlement).permit(:payee_id, :amount, :currency, :group_id, :notes, :settled_on)
  end

  def participant_error(settlement)
    if settlement.group_id.present?
      group = current_user.groups.find_by(id: settlement.group_id)
      return "Group not found" unless group
      "Payee must be a member of the group" unless group.active_memberships.exists?(user_id: settlement.payee_id)
    else
      "Payee must be one of your friends" unless current_user.all_friends.exists?(settlement.payee_id)
    end
  end
end
