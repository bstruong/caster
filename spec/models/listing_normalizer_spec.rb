require "rails_helper"

RSpec.describe ListingNormalizer do
  # Test surface: ListingNormalizer.new(raw_data, feed_profile).normalize
  #
  # Each example builds a minimal raw_data hash containing only the raw
  # column(s) it cares about. Other canonical fields come back as nil because
  # their raw keys aren't present in raw_data — that's the intended behavior.
  #
  # feed_columns.yml provides the canonical -> raw mapping for every CONVERTERS
  # entry, so the normalizer's @mappings.fetch(canonical) never raises in
  # happy-path examples. The "loud failure on drift" example deliberately
  # removes a mapping to assert the fetch raises.

  let(:feed_profile) { feed_profiles(:mlslistings_matrix) }

  def normalize(raw_data)
    described_class.new(raw_data, feed_profile).normalize
  end

  describe "string converter" do
    it "returns value when present" do
      expect(normalize("City" => "Sunnyvale")[:city]).to eq("Sunnyvale")
    end

    it "returns nil for blank value" do
      expect(normalize("City" => "")[:city]).to be_nil
    end

    it "returns nil when raw key missing" do
      expect(normalize({})[:city]).to be_nil
    end
  end

  describe "integer converter" do
    it "parses numeric string" do
      expect(normalize("Bd" => "4")[:bedrooms]).to eq(4)
    end

    it "returns nil for blank value" do
      expect(normalize("Bd" => "")[:bedrooms]).to be_nil
    end
  end

  describe "price_cents converter" do
    it "strips dollar sign and commas and converts to integer cents" do
      expect(normalize("Price" => "$1,500,000")[:list_price_cents]).to eq(150_000_000)
    end

    it "handles fractional dollars" do
      expect(normalize("Price" => "$1,500.50")[:list_price_cents]).to eq(150_050)
    end

    it "returns nil for blank value" do
      expect(normalize("Price" => "")[:list_price_cents]).to be_nil
    end
  end

  describe "date converter" do
    it "parses MM/DD/YYYY" do
      expect(normalize("Listed Date" => "04/01/2026")[:listed_at]).to eq(Date.new(2026, 4, 1))
    end

    it "returns nil for blank value" do
      expect(normalize("Listed Date" => "")[:listed_at]).to be_nil
    end
  end

  describe "decimal converter" do
    it "parses latitude as BigDecimal" do
      expect(normalize("Latitude" => "37.3688")[:latitude]).to eq(BigDecimal("37.3688"))
    end

    it "returns nil for blank value" do
      expect(normalize("Latitude" => "")[:latitude]).to be_nil
    end

    # Regression: #1 audit found latitude/longitude were silently dropped
    # before the CONVERTERS rewrite. Lock both in explicitly.
    it "carries both latitude and longitude through normalize" do
      result = normalize("Latitude" => "37.3688", "Longitude" => "-122.0363")
      expect(result[:latitude]).to eq(BigDecimal("37.3688"))
      expect(result[:longitude]).to eq(BigDecimal("-122.0363"))
    end
  end

  describe "sq_ft converter" do
    it "strips commas and converts to integer" do
      expect(normalize("Sq Ft Total" => "1,500")[:sq_ft_total]).to eq(1500)
    end

    it "returns nil for zero" do
      expect(normalize("Sq Ft Total" => "0")[:sq_ft_total]).to be_nil
    end

    it "returns nil for blank value" do
      expect(normalize("Sq Ft Total" => "")[:sq_ft_total]).to be_nil
    end
  end

  describe "lot_size converter" do
    it "strips Lot SqFt suffix and commas" do
      expect(normalize("Lot Size" => "5,000 Lot SqFt")[:lot_size_sqft]).to eq(5000)
    end

    it "returns nil when only suffix and whitespace" do
      expect(normalize("Lot Size" => " Lot SqFt")[:lot_size_sqft]).to be_nil
    end

    it "returns nil for blank value" do
      expect(normalize("Lot Size" => "")[:lot_size_sqft]).to be_nil
    end
  end

  describe "baths converter" do
    it "splits full and half on pipe" do
      result = normalize("Bths" => "2|1")
      expect(result[:full_baths]).to eq(2)
      expect(result[:half_baths]).to eq(1)
    end

    it "with no pipe returns full_baths only and nil half_baths" do
      result = normalize("Bths" => "2")
      expect(result[:full_baths]).to eq(2)
      expect(result[:half_baths]).to be_nil
    end

    it "returns both nil for blank value" do
      result = normalize("Bths" => "")
      expect(result[:full_baths]).to be_nil
      expect(result[:half_baths]).to be_nil
    end
  end

  describe "#normalize (cross-cutting)" do
    it "returns every canonical field key, even when raw_data is empty" do
      expected_keys = %i[
        mls_number listing_status street_address city state zip_code
        mls_area_id mls_area_name property_type property_sub_type
        construction_type building_type parking_features
        bedrooms parking_spaces garage_spaces age_years days_on_market
        list_price_cents sale_price_cents
        listed_at expires_at sale_agreed_at off_market_at closed_at
        latitude longitude
        sq_ft_total lot_size_sqft
        full_baths half_baths
      ]
      expect(normalize({}).keys.sort).to eq(expected_keys.sort)
    end

    it "raises KeyError when a CONVERTERS entry has no feed_columns mapping" do
      feed_profile.feed_columns.find_by!(canonical_field_name: "city").destroy
      expect { normalize("City" => "Sunnyvale") }.to raise_error(KeyError)
    end

    it "normalizes a representative raw row end-to-end" do
      raw = {
        "MLS Number" => "ML00000001",
        "S" => "A",
        "Address" => "100 Mathilda Ave",
        "City" => "Sunnyvale",
        "State" => "CA",
        "Zip" => "94087",
        "Area Name" => "Sunnyvale",
        "Bd" => "4",
        "Bths" => "2|1",
        "Sq Ft Total" => "1,500",
        "Lot Size" => "5,000 Lot SqFt",
        "Price" => "$1,500,000",
        "Listed Date" => "04/01/2026",
        "DOM" => "10",
        "Latitude" => "37.3688",
        "Longitude" => "-122.0363"
      }
      result = normalize(raw)

      expect(result[:mls_number]).to eq("ML00000001")
      expect(result[:listing_status]).to eq("A")
      expect(result[:street_address]).to eq("100 Mathilda Ave")
      expect(result[:city]).to eq("Sunnyvale")
      expect(result[:state]).to eq("CA")
      expect(result[:zip_code]).to eq("94087")
      expect(result[:mls_area_name]).to eq("Sunnyvale")
      expect(result[:bedrooms]).to eq(4)
      expect(result[:full_baths]).to eq(2)
      expect(result[:half_baths]).to eq(1)
      expect(result[:sq_ft_total]).to eq(1500)
      expect(result[:lot_size_sqft]).to eq(5000)
      expect(result[:list_price_cents]).to eq(150_000_000)
      expect(result[:listed_at]).to eq(Date.new(2026, 4, 1))
      expect(result[:days_on_market]).to eq(10)
      expect(result[:latitude]).to eq(BigDecimal("37.3688"))
      expect(result[:longitude]).to eq(BigDecimal("-122.0363"))
      expect(result[:sale_price_cents]).to be_nil
      expect(result[:closed_at]).to be_nil
    end
  end
end
