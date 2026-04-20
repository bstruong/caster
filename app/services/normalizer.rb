class Normalizer
  def initialize(raw_listing)
    @raw_listing = raw_listing
    @feed_profile = raw_listing.feed_profile
  end

  def normalize!
    attributes = ListingNormalizer.new(@raw_listing.raw_data, @feed_profile).normalize

    listing = Listing.find_or_initialize_by(mls_number: attributes[:mls_number])
    listing.assign_attributes(attributes.merge(raw_listing: @raw_listing))
    listing.save!

    ListingSnapshot.create!(
      listing:          listing,
      raw_listing:      @raw_listing,
      snapshot_date:    Date.current,
      listing_status:   listing.listing_status,
      list_price_cents: listing.list_price_cents,
      sale_price_cents: listing.sale_price_cents,
      days_on_market:   listing.days_on_market
    )

    listing
  end
end
