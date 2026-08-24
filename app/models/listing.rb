class Listing < ApplicationRecord
  belongs_to :raw_listing
  has_many :listing_snapshots

  # No validate: true on purpose -- an off-vocabulary status should raise
  # ArgumentError at assignment rather than be collected as a validation error,
  # matching the project's loud-failures principle. The presence validation
  # below covers the different case of nil/blank.
  enum :listing_status, {
    active:     "A",
    sold:       "S",
    pending:    "P",
    expired:    "E",
    withdrawn:  "W",
    contingent: "C"
  }

  validates :mls_number, presence: true, uniqueness: true
  validates :listing_status, presence: true
  validates :street_address, presence: true
  validates :city, presence: true
  validates :state, presence: true
  validates :zip_code, presence: true
  validates :list_price_cents, presence: true
  validates :listed_at, presence: true

  def self.upsert_from(attributes)
    listing = find_or_initialize_by(mls_number: attributes[:mls_number])
    listing.assign_attributes(attributes)
    listing.save!
    listing
  end
end
