require "rails_helper"

RSpec.describe Listing do
  describe ".upsert_from" do
    let(:raw_listing) { raw_listings(:raw_1) }

    let(:base_attributes) do
      {
        mls_number:       "ML99999999",
        listing_status:   "A",
        street_address:   "123 Test St",
        city:             "Sunnyvale",
        state:            "CA",
        zip_code:         "94087",
        list_price_cents: 100_000_000,
        listed_at:        Date.new(2026, 4, 1),
        raw_listing:      raw_listing
      }
    end

    it "creates a new listing when mls_number doesn't exist" do
      expect {
        Listing.upsert_from(base_attributes)
      }.to change(Listing, :count).by(1)
    end

    it "returns the persisted listing" do
      listing = Listing.upsert_from(base_attributes)
      expect(listing).to be_persisted
      expect(listing.mls_number).to eq("ML99999999")
    end

    it "updates an existing listing when mls_number already exists" do
      Listing.upsert_from(base_attributes)
      updated = base_attributes.merge(list_price_cents: 200_000_000)

      expect {
        Listing.upsert_from(updated)
      }.not_to change(Listing, :count)

      expect(Listing.find_by(mls_number: "ML99999999").list_price_cents).to eq(200_000_000)
    end

    it "assigns raw_listing reference on update" do
      Listing.upsert_from(base_attributes)
      other_raw = raw_listings(:raw_2)

      Listing.upsert_from(base_attributes.merge(raw_listing: other_raw))

      expect(Listing.find_by(mls_number: "ML99999999").raw_listing).to eq(other_raw)
    end

    it "raises ActiveRecord::RecordInvalid when validations fail" do
      expect {
        Listing.upsert_from(base_attributes.merge(mls_number: nil))
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
