class SettlementSerializer
  include JSONAPI::Serializer
  attributes :payer_id, :payee_id, :group_id, :amount, :currency, :notes, :settled_on, :created_at
end
