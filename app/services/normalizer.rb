class Normalizer
  def initialize(raw_listing)
    @raw_listing = raw_listing
    @feed_profile = raw_listing.feed_profile
  end

  def normalize!
    attributes = ListingNormalizer.new(@raw_listing.raw_data, @feed_profile).normalize
    listing = Listing.upsert_from(attributes.merge(raw_listing: @raw_listing))
    ListingSnapshot.capture(listing, @raw_listing)
    listing
  end
end
