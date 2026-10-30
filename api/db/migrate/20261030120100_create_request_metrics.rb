class CreateRequestMetrics < ActiveRecord::Migration[8.0]
  def change
    create_table :request_metrics do |t|
      t.datetime :minute, null: false
      t.integer :requests, null: false, default: 0
      t.integer :server_errors, null: false, default: 0
      t.integer :client_errors, null: false, default: 0
      t.integer :throttled, null: false, default: 0
      t.integer :blocked, null: false, default: 0
      t.float :total_ms, null: false, default: 0
      t.float :max_ms, null: false, default: 0
      t.float :p95_ms, null: false, default: 0
      t.json :statuses, null: false, default: {}
      t.json :endpoints, null: false, default: {}
    end
    add_index :request_metrics, :minute
  end
end
