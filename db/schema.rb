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

ActiveRecord::Schema[8.0].define(version: 2026_03_20_155056) do
  create_table "cards", force: :cascade do |t|
    t.string "name"
    t.string "edition"
    t.string "condition"
    t.string "language"
    t.string "foil"
    t.integer "quantity", default: 0
    t.string "collector_number"
    t.decimal "purchase_price", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "price", precision: 10, scale: 2
    t.string "scryfall_id"
    t.string "edition_name"
    t.string "price_source"
    t.boolean "price_reviewed", default: false, null: false
    t.string "foil_type"
    t.index ["edition"], name: "index_cards_on_edition"
    t.index ["name"], name: "index_cards_on_name"
    t.index ["scryfall_id"], name: "index_cards_on_scryfall_id"
  end

  create_table "cart_items", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "card_id", null: false
    t.integer "quantity", default: 1
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_id"], name: "index_cart_items_on_card_id"
    t.index ["user_id", "card_id"], name: "index_cart_items_on_user_id_and_card_id", unique: true
    t.index ["user_id"], name: "index_cart_items_on_user_id"
  end

  create_table "reservation_items", force: :cascade do |t|
    t.integer "reservation_id", null: false
    t.integer "card_id", null: false
    t.integer "quantity", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "unit_price", precision: 10, scale: 2
    t.index ["card_id"], name: "index_reservation_items_on_card_id"
    t.index ["reservation_id"], name: "index_reservation_items_on_reservation_id"
  end

  create_table "reservation_notes", force: :cascade do |t|
    t.integer "reservation_id", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reservation_id"], name: "index_reservation_notes_on_reservation_id"
  end

  create_table "reservation_payments", force: :cascade do |t|
    t.integer "reservation_id", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.string "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reservation_id"], name: "index_reservation_payments_on_reservation_id"
  end

  create_table "reservations", force: :cascade do |t|
    t.integer "user_id"
    t.string "status", default: "pending", null: false
    t.text "message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "guest_name"
    t.string "guest_contact"
    t.decimal "final_price", precision: 10, scale: 2
    t.string "payment_method"
    t.datetime "receipt_sent_at"
    t.boolean "trade", default: false, null: false
    t.index ["status"], name: "index_reservations_on_status"
    t.index ["user_id"], name: "index_reservations_on_user_id"
  end

  create_table "site_settings", force: :cascade do |t|
    t.boolean "maintenance_mode", default: false, null: false
    t.text "maintenance_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at", precision: nil
    t.datetime "remember_created_at", precision: nil
    t.string "name"
    t.string "phone_number"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "admin", default: false, null: false
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.string "locale", default: "es", null: false
    t.string "provider"
    t.string "uid"
    t.boolean "dismissed_how_it_works", default: false, null: false
    t.string "theme", default: "dark"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "cart_items", "cards"
  add_foreign_key "cart_items", "users"
  add_foreign_key "reservation_items", "cards"
  add_foreign_key "reservation_items", "reservations"
  add_foreign_key "reservation_notes", "reservations"
  add_foreign_key "reservation_payments", "reservations"
  add_foreign_key "reservations", "users"
end
