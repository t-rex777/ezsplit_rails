class BalancesController < ApplicationController
  before_action :set_group, only: %i[ group ]

  # GET /balances
  # One row per person and currency. Positive amount: they owe you. Negative: you owe them.
  def index
    render json: { data: balance_rows(BalanceCalculator.for_user(current_user)) }
  end

  # GET /groups/1/balances
  # One row per member and currency. Positive amount: the group owes them. Negative: they owe the group.
  def group
    render json: { data: balance_rows(BalanceCalculator.for_group(@group)) }
  end

  private

  def set_group
    @group = current_user.groups.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { errors: [ "Group not found" ] }, status: :not_found
  end

  def balance_rows(balances)
    users = User.where(id: balances.keys.map(&:first)).index_by(&:id)

    balances.map do |(user_id, currency), amount|
      user = users[user_id]
      {
        user_id: user_id,
        first_name: user&.first_name,
        last_name: user&.last_name,
        currency: currency,
        amount: amount.to_s("F")
      }
    end
  end
end
