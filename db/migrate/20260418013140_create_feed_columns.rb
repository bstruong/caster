class CreateFeedColumns < ActiveRecord::Migration[8.1]
  def change
    create_table :feed_columns do |t|
      t.references :feed_profile, null: false, foreign_key: true
      t.string  :raw_column_name,      null: false
      t.string  :canonical_field_name, null: false
      t.boolean :required,             null: false, default: false

      t.datetime :created_at, null: false
    end
  end
end
