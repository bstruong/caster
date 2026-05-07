require "rails_helper"

RSpec.describe PriceTrendQuery do
  # Fixture cheat sheet (zip 94087, area Sunnyvale):
  #   Active, listed_at in window:
  #     sunnyvale_active_1: 2026-04-01
  #     sunnyvale_active_2: 2026-03-15
  #     sunnyvale_active_3: 2026-02-10
  #     sunnyvale_active_4: 2025-11-05
  #   Active, listed_at outside window:
  #     stale_listing: 2024-01-01
  #   Sold, closed_at in window:
  #     sunnyvale_sold_1: closed 2025-09-15, list $1.8M, sale $1.9M
  #     sunnyvale_sold_2: closed 2026-01-20, list $2.1M, sale $2.05M

  include ActiveSupport::Testing::TimeHelpers

  before { travel_to Time.zone.parse("2026-05-02") }
  after  { travel_back }

  describe "#call" do
    it "returns one entry per month in window" do
      result = PriceTrendQuery.new(zip_code: "94087", status: "A").call
      expect(result.size).to eq(4)
    end

    it "groups active listings by listed_at" do
      result = PriceTrendQuery.new(zip_code: "94087", status: "A").call
      months = result.map { |entry| entry[:month] }
      expect(months).to eq(%w[2025-11 2026-02 2026-03 2026-04])
    end

    it "groups sold listings by closed_at" do
      result = PriceTrendQuery.new(zip_code: "94087", status: "S").call
      months = result.map { |entry| entry[:month] }
      expect(months).to eq(%w[2025-09 2026-01])
    end

    it "excludes listings outside the 12-month window" do
      result = PriceTrendQuery.new(zip_code: "94087", status: "A").call
      months = result.map { |entry| entry[:month] }
      expect(months).not_to include("2024-01")
    end

    it "returns nil sale metrics when no sales in month" do
      result = PriceTrendQuery.new(zip_code: "94087", status: "A").call
      entry = result.first
      expect(entry[:average_sale_price]).to be_nil
      expect(entry[:median_sale_price]).to be_nil
      expect(entry[:average_list_to_sale_ratio]).to be_nil
    end

    it "formats month as YYYY-MM" do
      result = PriceTrendQuery.new(zip_code: "94087", status: "A").call
      entry = result.first
      expect(entry[:month]).to be_a(String)
      expect(entry[:month]).to match(/\A\d{4}-\d{2}\z/)
    end
  end
end
