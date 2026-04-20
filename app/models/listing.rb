class Listing < ApplicationRecord
  belongs_to :raw_listing
  has_many :listing_snapshots

  validates :mls_number, presence: true, uniqueness: true
  validates :listing_status, presence: true
  validates :street_address, presence: true
  validates :city, presence: true
  validates :state, presence: true
  validates :zip_code, presence: true
  validates :list_price_cents, presence: true
  validates :listed_at, presence: true
end
