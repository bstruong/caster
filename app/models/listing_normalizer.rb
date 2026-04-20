class ListingNormalizer
  def initialize(raw_data, feed_profile)
    @raw_data = raw_data
    @feed_profile = feed_profile
  end

  def normalize
    {
      mls_number:        field("MLS #"),
      listing_status:    field("S"),
      street_address:    field("Address"),
      city:              field("City"),
      state:             field("St"),
      zip_code:          field("Zip"),
      mls_area_id:       field("Area"),
      mls_area_name:     field("Area Name"),
      property_type:     field("Type"),
      property_sub_type: field("Sub Type"),
      bedrooms:          integer(field("Beds")),
      full_baths:        full_baths,
      half_baths:        half_baths,
      sq_ft_total:       sq_ft_total,
      lot_size_sqft:     lot_size_sqft,
      age_years:         nullable_integer(field("Age")),
      construction_type: nullable_string(field("Construction Type")),
      building_type:     field("Building Type"),
      parking_features:  field("Parking Features"),
      parking_spaces:    integer(field("Parking Spaces")),
      garage_spaces:     integer(field("Garage Spaces")),
      list_price_cents:  price_cents(field("Price")),
      sale_price_cents:  price_cents(field("Sale Price")),
      listed_at:         date(field("List Date")),
      expires_at:        date(field("Expiration Date")),
      sale_agreed_at:    date(field("Sale Date")),
      off_market_at:     date(field("Off Market Date")),
      closed_at:         date(field("Close Date")),
      days_on_market:    nullable_integer(field("DOM"))
    }
  end

  private

  def field(raw_column_name)
    mapping = @feed_profile.feed_columns.find_by(raw_column_name: raw_column_name)
    return nil unless mapping
    @raw_data[raw_column_name]
  end

  def price_cents(value)
    return nil if value.nil? || value.strip.empty?
    (value.gsub(/[$,]/, "").to_f * 100).to_i
  end

  def full_baths
    bths = field("Bths")
    return nil if bths.nil? || bths.strip.empty?
    bths.split("|").first.to_i
  end

  def half_baths
    bths = field("Bths")
    return nil if bths.nil? || bths.strip.empty?
    bths.split("|").last.to_i
  end

  def sq_ft_total
    value = field("Sq Ft Total")
    return nil if value.nil? || value.strip.empty?
    sq_ft = value.gsub(",", "").to_i
    sq_ft.zero? ? nil : sq_ft
  end

  def lot_size_sqft
    value = field("Lot Size")
    return nil if value.nil? || value.strip.empty?
    value.gsub(/Lot SqFt|,/, "").strip.then { |v| v.empty? ? nil : v.to_i }
  end

  def integer(value)
    return nil if value.nil? || value.strip.empty?
    value.to_i
  end

  def nullable_integer(value)
    return nil if value.nil? || value.strip.empty?
    value.to_i
  end

  def nullable_string(value)
    return nil if value.nil? || value.strip.empty?
    value
  end

  def date(value)
    return nil if value.nil? || value.strip.empty?
    Date.strptime(value, "%m/%d/%Y")
  end
end
