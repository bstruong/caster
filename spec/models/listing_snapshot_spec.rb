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

    it "copies listing_status from the listing" do
      snapshot = ListingSnapshot.capture(listing, raw_listing)
      expect(snapshot.listing_status).to eq(listing.listing_status)
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
