require "rails_helper"

RSpec.describe ListingSnapshot do
  include ActiveSupport::Testing::TimeHelpers

  describe ".capture" do
    let(:listing)     { listings(:sunnyvale_active_1) }
    let(:raw_listing) { raw_listings(:raw_1) }

    it "creates a snapshot record" do
      expect {
        ListingSnapshot.capture(listing, raw_listing)
      }.to change(ListingSnapshot, :count).by(1)
    end

    it "returns the persisted snapshot" do
      snapshot = ListingSnapshot.capture(listing, raw_listing)
      expect(snapshot).to be_persisted
    end

    it "sets snapshot_date to the current date" do
      travel_to Time.zone.parse("2026-05-15") do
        snapshot = ListingSnapshot.capture(listing, raw_listing)
        expect(snapshot.snapshot_date).to eq(Date.new(2026, 5, 15))
      end
    end

    it "copies the raw listing_status code, not the enum label" do
      snapshot = ListingSnapshot.capture(listing, raw_listing)
      # Asserted as a literal rather than against listing.listing_status:
      # Listing has an enum so that accessor returns "active", while
      # listing_snapshots stores raw codes. Comparing the two accessors is
      # what let the label leak into snapshots go unnoticed.
      expect(snapshot.listing_status).to eq("A")
      expect(listing.listing_status).to eq("active")
    end

    # Every code in the vocabulary, not just "A". A plain each-loop rather than
    # shared_examples: this repo uses shared_examples nowhere, and the mapping is
    # flat tabular data (spec/fixtures/feed_columns.yml drives its rows the same
    # way). Attributes are built in memory against a fixture raw_listing, mirroring
    # spec/models/listing_spec.rb, instead of adding five more YAML fixtures.
    #
    # Assignment is by RAW CODE because that is what really happens:
    # ListingNormalizer maps listing_status as :passthrough, so the CSV's code
    # reaches Listing untouched. Going through Listing.upsert_from also matches
    # Normalizer's real path and guarantees the record is saved before capture
    # reads listing_status_before_type_cast -- pre-save that accessor can still
    # hand back a label.
    {
      "A" => "active",
      "S" => "sold",
      "P" => "pending",
      "E" => "expired",
      "W" => "withdrawn",
      "C" => "contingent"
    }.each do |code, label|
      it "stores raw code #{code.inspect} in the snapshot while the listing reads #{label.inspect}" do
        listing = Listing.upsert_from(
          mls_number:       "MLSTATUS#{code}",
          listing_status:   code,
          street_address:   "1 Status Way",
          city:             "Sunnyvale",
          state:            "CA",
          zip_code:         "94087",
          list_price_cents: 100_000_000,
          listed_at:        Date.new(2026, 4, 1),
          raw_listing:      raw_listing
        )

        snapshot = ListingSnapshot.capture(listing, raw_listing)

        expect(snapshot.listing_status).to eq(code)
        expect(listing.listing_status).to eq(label)
      end
    end

    it "copies list_price_cents from the listing" do
      snapshot = ListingSnapshot.capture(listing, raw_listing)
      expect(snapshot.list_price_cents).to eq(listing.list_price_cents)
    end

    it "copies sale_price_cents from the listing" do
      sold_listing = listings(:sunnyvale_sold_1)
      snapshot = ListingSnapshot.capture(sold_listing, raw_listing)
      expect(snapshot.sale_price_cents).to eq(sold_listing.sale_price_cents)
    end

    it "copies days_on_market from the listing" do
      snapshot = ListingSnapshot.capture(listing, raw_listing)
      expect(snapshot.days_on_market).to eq(listing.days_on_market)
    end

    it "links the snapshot to the listing" do
      snapshot = ListingSnapshot.capture(listing, raw_listing)
      expect(snapshot.listing).to eq(listing)
    end

    it "links the snapshot to the raw_listing" do
      snapshot = ListingSnapshot.capture(listing, raw_listing)
      expect(snapshot.raw_listing).to eq(raw_listing)
    end
  end
end
