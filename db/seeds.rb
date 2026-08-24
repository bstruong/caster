# Seeds the feed configuration the pipeline needs in order to run at all.
#
# ListingNormalizer#field looks its raw column up with mappings.fetch(canonical),
# which raises KeyError on a miss, so every canonical name in
# ListingNormalizer::CONVERTERS must have a FeedColumn row here -- plus "baths",
# which is handled separately in #baths_pair and is therefore not in CONVERTERS.
#
# Raw column names below match spec/fixtures/feed_columns.yml exactly, so the
# seeded configuration and the one the suite exercises cannot drift apart.
#
# Idempotent: re-running updates the existing rows in place rather than
# inserting duplicates.

MLSLISTINGS_MATRIX_COLUMNS = {
  "mls_number"        => "MLS Number",
  "listing_status"    => "S",
  "street_address"    => "Address",
  "city"              => "City",
  "state"             => "State",
  "zip_code"          => "Zip",
  "mls_area_id"       => "Area",
  "mls_area_name"     => "Area Name",
  "property_type"     => "Property Type",
  "property_sub_type" => "Property Sub Type",
  "construction_type" => "Construction Type",
  "building_type"     => "Building Type",
  "parking_features"  => "Parking Features",
  "bedrooms"          => "Bd",
  "parking_spaces"    => "Parking Spaces",
  "garage_spaces"     => "Garage Spaces",
  "age_years"         => "Age",
  "days_on_market"    => "DOM",
  "list_price_cents"  => "Price",
  "sale_price_cents"  => "Sale Price",
  "listed_at"         => "Listed Date",
  "expires_at"        => "Expires Date",
  "sale_agreed_at"    => "Sale Agreed Date",
  "off_market_at"     => "Off Market Date",
  "closed_at"         => "Closed Date",
  "latitude"          => "Latitude",
  "longitude"         => "Longitude",
  "sq_ft_total"       => "Sq Ft Total",
  "lot_size_sqft"     => "Lot Size",
  "baths"             => "Bths"
}.freeze

# FeedProfileValidator raises MissingRequiredColumnsError when a CSV is missing
# one of these headers. The list is exactly the set of canonical fields backed by
# a NOT NULL column on `listings` -- without any one of them the row cannot be
# stored, so failing loudly at validation beats failing later on insert.
MLSLISTINGS_MATRIX_REQUIRED = %w[
  mls_number
  listing_status
  street_address
  city
  state
  zip_code
  list_price_cents
  listed_at
].freeze

ActiveRecord::Base.transaction do
  profile = FeedProfile.find_or_initialize_by(source_identifier: "mlslistings_matrix")
  profile.name = "MLSListings Matrix"
  profile.description = "Manual CSV exports from MLSListings Matrix"
  profile.save!

  MLSLISTINGS_MATRIX_COLUMNS.each do |canonical_field_name, raw_column_name|
    column = FeedColumn.find_or_initialize_by(
      feed_profile:         profile,
      canonical_field_name: canonical_field_name
    )
    column.raw_column_name = raw_column_name
    column.required = MLSLISTINGS_MATRIX_REQUIRED.include?(canonical_field_name)
    column.save!
  end

  puts "Seeded #{profile.source_identifier}: " \
       "#{profile.feed_columns.count} feed columns " \
       "(#{profile.feed_columns.where(required: true).count} required)"
end
