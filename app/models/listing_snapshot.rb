class ListingSnapshot < ApplicationRecord
  belongs_to :listing
  belongs_to :raw_listing

  validates :snapshot_date, presence: true
  validates :listing_status, presence: true
  validates :list_price_cents, presence: true
end
