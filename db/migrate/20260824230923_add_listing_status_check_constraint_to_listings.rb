class AddListingStatusCheckConstraintToListings < ActiveRecord::Migration[8.1]
  def change
    # Defense-in-depth behind Listing's enum: the enum raises ArgumentError on a
    # bad assignment through ActiveRecord, but nothing stops raw SQL, a bulk
    # insert, or psql from writing an off-vocabulary status. Vocabulary is
    # documented in AGENTS.md "Listing Status Vocabulary".
    #
    # Deliberately NOT applied to listing_snapshots: that table is an
    # append-only historical record, not a live business object.
    add_check_constraint :listings,
                         "listing_status IN ('A', 'S', 'P', 'E', 'W', 'C')",
                         name: "listings_listing_status_check"
  end
end
