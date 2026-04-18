class CreateListings < ActiveRecord::Migration[8.1]
  def change
    create_table :listings do |t|
      t.references :raw_listing, null: false, foreign_key: true
      t.string  :mls_number,       null: false
      t.string  :listing_status,   null: false
      t.string  :street_address,   null: false
      t.string  :city,             null: false
      t.string  :state,            null: false
      t.string  :zip_code,         null: false
      t.decimal :latitude,         precision: 10, scale: 7
      t.decimal :longitude,        precision: 10, scale: 7
      t.string  :mls_area_id
      t.string  :mls_area_name
      t.string  :property_type
      t.string  :property_sub_type
      t.integer :bedrooms
      t.integer :full_baths
      t.integer :half_baths
      t.integer :sq_ft_total
      t.integer :lot_size_sqft
      t.integer :age_years
      t.string  :construction_type
      t.text    :building_type
      t.text    :parking_features
      t.integer :parking_spaces
      t.integer :garage_spaces
      t.bigint  :list_price_cents,  null: false
      t.bigint  :sale_price_cents
      t.date    :listed_at,         null: false
      t.date    :expires_at
      t.date    :sale_agreed_at
      t.date    :off_market_at
      t.date    :closed_at
      t.integer :days_on_market

      t.timestamps
    end

    add_index :listings, :mls_number, unique: true
  end
end
