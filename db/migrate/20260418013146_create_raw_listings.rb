class CreateRawListings < ActiveRecord::Migration[8.1]
  def change
    create_table :raw_listings do |t|
      t.references :feed_profile, null: false, foreign_key: true
      t.jsonb   :raw_data,    null: false
      t.string  :source_file
      t.datetime  :ingested_at, null: false
    end
  end
end
