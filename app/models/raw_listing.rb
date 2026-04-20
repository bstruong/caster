class RawListing < ApplicationRecord
  belongs_to :feed_profile
  has_many :listings
  has_many :listing_snapshots
end
