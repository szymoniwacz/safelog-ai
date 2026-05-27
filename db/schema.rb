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

ActiveRecord::Schema[8.1].define(version: 2026_05_27_152734) do
  create_table "debugging_cases", force: :cascade do |t|
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.text "customer_reference"
    t.text "description"
    t.string "environment"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_debugging_cases_on_user_id"
  end

  create_table "log_sources", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "debugging_case_id", null: false
    t.string "name"
    t.integer "position", default: 0, null: false
    t.text "sanitized_content"
    t.string "source_type", null: false
    t.datetime "updated_at", null: false
    t.index ["debugging_case_id"], name: "index_log_sources_on_debugging_case_id"
  end

  create_table "redaction_findings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "finding_type", null: false
    t.integer "line_number", null: false
    t.integer "log_source_id", null: false
    t.string "placeholder", null: false
    t.string "risk_level", null: false
    t.datetime "updated_at", null: false
    t.index ["log_source_id"], name: "index_redaction_findings_on_log_source_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "debugging_cases", "users"
  add_foreign_key "log_sources", "debugging_cases"
  add_foreign_key "redaction_findings", "log_sources"
end
