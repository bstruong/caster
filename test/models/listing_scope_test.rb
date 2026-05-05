require "test_helper"

class ListingScopeTest < ActiveSupport::TestCase
  def test_filters_by_zip_code
    scope = ListingScope.new(zip_code: "94087", area_name: nil, status: "A")
    mls_numbers = scope.to_relation.pluck(:mls_number)
    assert_equal 5, mls_numbers.size
    refute_includes mls_numbers, "ML00000007"  # cupertino_active_1
  end

  def test_filters_by_area_name
    scope = ListingScope.new(zip_code: nil, area_name: "Cupertino", status: "A")
    assert_equal [ "ML00000007" ], scope.to_relation.pluck(:mls_number)
  end

  def test_filters_by_status
    scope = ListingScope.new(zip_code: "94087", area_name: nil, status: "S")
    assert_equal %w[ML00000005 ML00000006], scope.to_relation.pluck(:mls_number).sort
  end

  def test_raises_when_both_zip_and_area_provided
    err = assert_raises(ArgumentError) do
      ListingScope.new(zip_code: "94087", area_name: "Sunnyvale", status: "A")
    end
    assert_equal "Provide zip_code or area_name, not both", err.message
  end

  def test_raises_when_neither_zip_nor_area_provided
    err = assert_raises(ArgumentError) do
      ListingScope.new(zip_code: nil, area_name: nil, status: "A")
    end
    assert_equal "zip_code or area_name is required", err.message
  end

  def test_status_reader_exposes_value
    scope = ListingScope.new(zip_code: "94087", area_name: nil, status: "S")
    assert_equal "S", scope.status
  end
end
