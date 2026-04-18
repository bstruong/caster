class CreateFeedProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :feed_profiles do |t|
      t.string :name,              null: false
      t.string :source_identifier, null: false
      t.string :description

      t.timestamps
    end
  end
end
