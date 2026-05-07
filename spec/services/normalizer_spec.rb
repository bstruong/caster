require "rails_helper"

RSpec.describe Normalizer do
  let(:feed_profile) { feed_profiles(:mlslistings_matrix) }

  let(:raw_data) do
    {
      "MLS Number"   => "ML00099999",
      "S"            => "A",
      "Address"      => "999 Test Ave",
      "City"         => "Sunnyvale",
      "State"        => "CA",
      "Zip"          => "94087",
      "Area Name"    => "Sunnyvale",
      "Bd"           => "3",
      "Bths"         => "2|1",
      "Sq Ft Total"  => "1,800",
      "Lot Size"     => "5,500 Lot SqFt",
      "Price"        => "$1,800,000",
      "Listed Date"  => "04/01/2026",
      "DOM"          => "12",
      "Latitude"     => "37.3688",
      "Longitude"    => "-122.0363"
    }
  end

  let(:raw_listing) do
    RawListing.create!(
      feed_profile: feed_profile,
      raw_data:     raw_data,
      source_file:  "test.csv",
      ingested_at:  Time.current
    )
  end

  describe "#normalize!" do
    it "creates a new Listing on first run" do
      expect {
        Normalizer.new(raw_listing).normalize!
      }.to change(Listing, :count).by(1)
    end

    it "returns the persisted listing" do
      result = Normalizer.new(raw_listing).normalize!
      expect(result).to be_a(Listing)
      expect(result).to be_persisted
      expect(result.mls_number).to eq("ML00099999")
    end

    it "applies normalized attributes to the listing" do
      listing = Normalizer.new(raw_listing).normalize!
      expect(listing.list_price_cents).to eq(180_000_000)
      expect(listing.bedrooms).to eq(3)
      expect(listing.full_baths).to eq(2)
      expect(listing.half_baths).to eq(1)
      expect(listing.sq_ft_total).to eq(1800)
      expect(listing.listed_at).to eq(Date.new(2026, 4, 1))
    end

    it "updates an existing Listing on a subsequent run with the same mls_number" do
      Normalizer.new(raw_listing).normalize!

      updated_raw_listing = RawListing.create!(
        feed_profile: feed_profile,
        raw_data:     raw_data.merge("Price" => "$2,000,000"),
        source_file:  "test_update.csv",
        ingested_at:  Time.current
      )

      expect {
        Normalizer.new(updated_raw_listing).normalize!
      }.not_to change(Listing, :count)

      listing = Listing.find_by(mls_number: "ML00099999")
      expect(listing.list_price_cents).to eq(200_000_000)
    end

    it "creates a new ListingSnapshot every run" do
      expect {
        Normalizer.new(raw_listing).normalize!
      }.to change(ListingSnapshot, :count).by(1)

      second_raw_listing = RawListing.create!(
        feed_profile: feed_profile,
        raw_data:     raw_data,
        source_file:  "test_2.csv",
        ingested_at:  Time.current
      )

      expect {
        Normalizer.new(second_raw_listing).normalize!
      }.to change(ListingSnapshot, :count).by(1)
    end

    it "links the snapshot to the upserted listing" do
      listing = Normalizer.new(raw_listing).normalize!
      snapshot = listing.listing_snapshots.last
      expect(snapshot.listing).to eq(listing)
    end

    it "links the snapshot to the source raw_listing" do
      Normalizer.new(raw_listing).normalize!
      snapshot = ListingSnapshot.find_by(raw_listing: raw_listing)
      expect(snapshot).not_to be_nil
      expect(snapshot.raw_listing).to eq(raw_listing)
    end

    it "snapshot reflects the listing's normalized state" do
      listing = Normalizer.new(raw_listing).normalize!
      snapshot = listing.listing_snapshots.last
      expect(snapshot.listing_status).to eq(listing.listing_status)
      expect(snapshot.list_price_cents).to eq(listing.list_price_cents)
      expect(snapshot.days_on_market).to eq(listing.days_on_market)
    end
  end
end
