class CreateAppErrors < ActiveRecord::Migration[8.0]
  def change
    create_table :app_errors do |t|
      t.string :fingerprint, null: false
      t.string :error_class, null: false
      t.text :message
      t.text :backtrace
      t.string :severity, null: false
      t.boolean :handled, null: false, default: false
      t.string :source
      t.json :context, null: false, default: {}
      t.integer :occurrences, null: false, default: 1
      t.datetime :first_seen_at, null: false
      t.datetime :last_seen_at, null: false
      t.timestamps
    end
    add_index :app_errors, :fingerprint, unique: true
    add_index :app_errors, :last_seen_at
  end
end
