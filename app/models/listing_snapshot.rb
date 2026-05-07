class ListingSnapshot < ApplicationRecord
  belongs_to :listing
  belongs_to :raw_listing

  validates :snapshot_date, presence: true
  validates :listing_status, presence: true
  validates :list_price_cents, presence: true

  def self.capture(listing, raw_listing)
    create!(
      listing:          listing,
      raw_listing:      raw_listing,
      snapshot_date:    Date.current,
      listing_status:   listing.listing_status,
      list_price_cents: listing.list_price_cents,
      sale_price_cents: listing.sale_price_cents,
      days_on_market:   listing.days_on_market
    )
  end
end
