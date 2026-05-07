require "rails_helper"

RSpec.describe MarketSummaryQuery do
  # Fixture cheat sheet (zip 94087, area Sunnyvale, status A, in 12-month window):
  #   sunnyvale_active_1: $1.5M, 1500 sqft, 10 DOM
  #   sunnyvale_active_2: $1.75M, 1750 sqft, 20 DOM
  #   sunnyvale_active_3: $2M, 2000 sqft, 30 DOM
  #   sunnyvale_active_4: $2.25M, 2250 sqft, 40 DOM
  #   stale_listing:      $1M,   1000 sqft, 500 DOM (also matches — listed_at is irrelevant here)

  describe "#call" do
    it "returns listings count" do
      result = MarketSummaryQuery.new(zip_code: "94087", status: "A").call
      expect(result[:listings_count]).to eq(5)
    end

    it "returns average list price in dollars" do
      result = MarketSummaryQuery.new(zip_code: "94087", status: "A").call
      expect(result[:average_list_price]).to eq(1_700_000.00)
    end

    it "returns median list price in dollars" do
      result = MarketSummaryQuery.new(zip_code: "94087", status: "A").call
      expect(result[:median_list_price]).to eq(1_750_000.00)
    end

    it "returns average days on market" do
      result = MarketSummaryQuery.new(zip_code: "94087", status: "A").call
      expect(result[:average_days_on_market]).to eq(120.0)
    end

    it "returns average price per sqft" do
      result = MarketSummaryQuery.new(zip_code: "94087", status: "A").call
      expect(result[:average_price_per_sqft]).to eq(1_000.00)
    end

    it "scopes to zip code" do
      result = MarketSummaryQuery.new(zip_code: "95014", status: "A").call
      expect(result[:listings_count]).to eq(1)
    end

    it "scopes to area name" do
      result = MarketSummaryQuery.new(area_name: "Cupertino", status: "A").call
      expect(result[:listings_count]).to eq(1)
    end

    it "returns nil median when no listings match" do
      result = MarketSummaryQuery.new(zip_code: "00000", status: "A").call
      expect(result[:listings_count]).to eq(0)
      expect(result[:median_list_price]).to be_nil
    end
  end
end
