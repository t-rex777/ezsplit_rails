# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_08_27_113931) do
  create_table "categories", force: :cascade do |t|
    t.string "name"
    t.string "icon"
    t.string "color"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_categories_on_user_id"
  end

  create_table "expenses", force: :cascade do |t|
    t.string "name"
    t.string "notes"
    t.decimal "amount"
    t.string "currency"
    t.integer "payer_id", null: false
    t.integer "group_id", null: false
    t.integer "category_id", null: false
    t.string "split_type"
    t.date "expense_date"
    t.boolean "settled"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["category_id"], name: "index_expenses_on_category_id"
    t.index ["group_id"], name: "index_expenses_on_group_id"
    t.index ["payer_id"], name: "index_expenses_on_payer_id"
    t.index ["user_id"], name: "index_expenses_on_user_id"
  end

  create_table "expenses_users", force: :cascade do |t|
    t.integer "expense_id", null: false
    t.integer "user_id", null: false
    t.decimal "amount"
    t.boolean "paid"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expense_id"], name: "index_expenses_users_on_expense_id"
    t.index ["user_id"], name: "index_expenses_users_on_user_id"
  end

  create_table "group_memberships", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "group_id", null: false
    t.date "joined_at"
    t.date "left_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group_id"], name: "index_group_memberships_on_group_id"
    t.index ["user_id"], name: "index_group_memberships_on_user_id"
  end

  create_table "groups", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.integer "created_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["created_by_id"], name: "index_groups_on_created_by_id"
    t.index ["user_id"], name: "index_groups_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "phone"
    t.string "avatar_url"
    t.date "date_of_birth"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "categories", "users"
  add_foreign_key "expenses", "categories"
  add_foreign_key "expenses", "groups"
  add_foreign_key "expenses", "users"
  add_foreign_key "expenses", "users", column: "payer_id"
  add_foreign_key "expenses_users", "expenses"
  add_foreign_key "expenses_users", "users"
  add_foreign_key "group_memberships", "groups"
  add_foreign_key "group_memberships", "users"
  add_foreign_key "groups", "users"
  add_foreign_key "groups", "users", column: "created_by_id"
  add_foreign_key "sessions", "users"
end
