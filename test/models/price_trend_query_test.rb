require "test_helper"

class PriceTrendQueryTest < ActiveSupport::TestCase
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

  setup do
    travel_to Time.zone.parse("2026-05-02")
  end

  def test_returns_one_entry_per_month_in_window
    result = PriceTrendQuery.new(zip_code: "94087", status: "A").call
    assert_equal 4, result.size
  end

  def test_groups_active_listings_by_listed_at
    result = PriceTrendQuery.new(zip_code: "94087", status: "A").call
    months = result.map { |entry| entry[:month] }
    assert_equal %w[2025-11 2026-02 2026-03 2026-04], months
  end

  def test_groups_sold_listings_by_closed_at
    result = PriceTrendQuery.new(zip_code: "94087", status: "S").call
    months = result.map { |entry| entry[:month] }
    assert_equal %w[2025-09 2026-01], months
  end

  def test_excludes_listings_outside_12_month_window
    result = PriceTrendQuery.new(zip_code: "94087", status: "A").call
    months = result.map { |entry| entry[:month] }
    refute_includes months, "2024-01"
  end

  def test_returns_nil_sale_metrics_when_no_sales_in_month
    result = PriceTrendQuery.new(zip_code: "94087", status: "A").call
    entry = result.first
    assert_nil entry[:average_sale_price]
    assert_nil entry[:median_sale_price]
    assert_nil entry[:average_list_to_sale_ratio]
  end

  def test_formats_month_as_yyyy_mm
    result = PriceTrendQuery.new(zip_code: "94087", status: "A").call
    entry = result.first
    assert_kind_of String, entry[:month]
    assert_match(/\A\d{4}-\d{2}\z/, entry[:month])
  end
end
