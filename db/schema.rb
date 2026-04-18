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

ActiveRecord::Schema[8.1].define(version: 2026_04_18_013157) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "feed_columns", force: :cascade do |t|
    t.string "canonical_field_name", null: false
    t.datetime "created_at", null: false
    t.bigint "feed_profile_id", null: false
    t.string "raw_column_name", null: false
    t.boolean "required", default: false, null: false
    t.index ["feed_profile_id"], name: "index_feed_columns_on_feed_profile_id"
  end

  create_table "feed_profiles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.string "name", null: false
    t.string "source_identifier", null: false
    t.datetime "updated_at", null: false
  end

  create_table "listing_snapshots", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "days_on_market"
    t.bigint "list_price_cents", null: false
    t.bigint "listing_id", null: false
    t.string "listing_status", null: false
    t.bigint "raw_listing_id", null: false
    t.bigint "sale_price_cents"
    t.date "snapshot_date", null: false
    t.index ["listing_id"], name: "index_listing_snapshots_on_listing_id"
    t.index ["raw_listing_id"], name: "index_listing_snapshots_on_raw_listing_id"
  end

  create_table "listings", force: :cascade do |t|
    t.integer "age_years"
    t.integer "bedrooms"
    t.text "building_type"
    t.string "city", null: false
    t.date "closed_at"
    t.string "construction_type"
    t.datetime "created_at", null: false
    t.integer "days_on_market"
    t.date "expires_at"
    t.integer "full_baths"
    t.integer "garage_spaces"
    t.integer "half_baths"
    t.decimal "latitude", precision: 10, scale: 7
    t.bigint "list_price_cents", null: false
    t.date "listed_at", null: false
    t.string "listing_status", null: false
    t.decimal "longitude", precision: 10, scale: 7
    t.integer "lot_size_sqft"
    t.string "mls_area_id"
    t.string "mls_area_name"
    t.string "mls_number", null: false
    t.date "off_market_at"
    t.text "parking_features"
    t.integer "parking_spaces"
    t.string "property_sub_type"
    t.string "property_type"
    t.bigint "raw_listing_id", null: false
    t.date "sale_agreed_at"
    t.bigint "sale_price_cents"
    t.integer "sq_ft_total"
    t.string "state", null: false
    t.string "street_address", null: false
    t.datetime "updated_at", null: false
    t.string "zip_code", null: false
    t.index ["mls_number"], name: "index_listings_on_mls_number", unique: true
    t.index ["raw_listing_id"], name: "index_listings_on_raw_listing_id"
  end

  create_table "raw_listings", force: :cascade do |t|
    t.bigint "feed_profile_id", null: false
    t.datetime "ingested_at", null: false
    t.jsonb "raw_data", null: false
    t.string "source_file"
    t.index ["feed_profile_id"], name: "index_raw_listings_on_feed_profile_id"
  end

  add_foreign_key "feed_columns", "feed_profiles"
  add_foreign_key "listing_snapshots", "listings"
  add_foreign_key "listing_snapshots", "raw_listings"
  add_foreign_key "listings", "raw_listings"
  add_foreign_key "raw_listings", "feed_profiles"
end
