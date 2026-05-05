require "test_helper"

class MarketSummaryQueryTest < ActiveSupport::TestCase
  # Fixture cheat sheet (zip 94087, area Sunnyvale, status A, in 12-month window):
  #   sunnyvale_active_1: $1.5M, 1500 sqft, 10 DOM
  #   sunnyvale_active_2: $1.75M, 1750 sqft, 20 DOM
  #   sunnyvale_active_3: $2M, 2000 sqft, 30 DOM
  #   sunnyvale_active_4: $2.25M, 2250 sqft, 40 DOM
  #   stale_listing:      $1M,   1000 sqft, 500 DOM (also matches — listed_at is irrelevant here)

  def test_returns_listings_count
    result = MarketSummaryQuery.new(zip_code: "94087", status: "A").call
    assert_equal 5, result[:listings_count]
  end

  def test_returns_average_list_price_in_dollars
    result = MarketSummaryQuery.new(zip_code: "94087", status: "A").call
    assert_equal 1_700_000.00, result[:average_list_price]
  end

  def test_returns_median_list_price_in_dollars
    result = MarketSummaryQuery.new(zip_code: "94087", status: "A").call
    assert_equal 1_750_000.00, result[:median_list_price]
  end

  def test_returns_average_days_on_market
    result = MarketSummaryQuery.new(zip_code: "94087", status: "A").call
    assert_equal 120.0, result[:average_days_on_market]
  end

  def test_returns_average_price_per_sqft
    result = MarketSummaryQuery.new(zip_code: "94087", status: "A").call
    assert_equal 1_000.00, result[:average_price_per_sqft]
  end

  def test_scopes_to_zip_code
    result = MarketSummaryQuery.new(zip_code: "95014", status: "A").call
    assert_equal 1, result[:listings_count]
  end

  def test_scopes_to_area_name
    result = MarketSummaryQuery.new(area_name: "Cupertino", status: "A").call
    assert_equal 1, result[:listings_count]
  end

  def test_returns_nil_median_when_no_listings_match
    result = MarketSummaryQuery.new(zip_code: "00000", status: "A").call
    assert_equal 0, result[:listings_count]
    assert_nil result[:median_list_price]
  end
end
