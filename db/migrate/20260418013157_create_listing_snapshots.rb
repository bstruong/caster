class CreateListingSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :listing_snapshots do |t|
      t.references :listing,     null: false, foreign_key: true
      t.references :raw_listing, null: false, foreign_key: true
      t.date    :snapshot_date,       null: false
      t.string  :listing_status,      null: false
      t.bigint  :list_price_cents,    null: false
      t.bigint  :sale_price_cents
      t.integer :days_on_market

      t.datetime :created_at, null: false
    end
  end
end
