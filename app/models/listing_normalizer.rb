class ListingNormalizer
  CONVERTERS = {
    "mls_number" => :passthrough,
    "listing_status" => :passthrough,
    "street_address" => :passthrough,
    "city" => :passthrough,
    "state" => :passthrough,
    "zip_code" => :passthrough,
    "mls_area_id" => :passthrough,
    "mls_area_name" => :passthrough,
    "property_type" => :passthrough,
    "property_sub_type" => :passthrough,
    "construction_type" => :passthrough,
    "building_type" => :passthrough,
    "parking_features" => :passthrough,
    "bedrooms" => :integer,
    "parking_spaces" => :integer,
    "garage_spaces" => :integer,
    "age_years" => :integer,
    "days_on_market" => :integer,
    "list_price_cents" => :price_cents,
    "sale_price_cents" => :price_cents,
    "listed_at" => :date,
    "expires_at" => :date,
    "sale_agreed_at" => :date,
    "off_market_at" => :date,
    "closed_at" => :date,
    "latitude" => :decimal,
    "longitude" => :decimal,
    "sq_ft_total" => :sq_ft,
    "lot_size_sqft" => :lot_size
    # "baths" handled separately in #normalize — splits one raw value into
    # full_baths + half_baths, doesn't fit the one-canonical-name-per-entry shape.
  }.freeze

  def initialize(raw_data, feed_profile)
    @raw_data = raw_data
    @mappings = feed_profile.feed_columns.pluck(:canonical_field_name, :raw_column_name).to_h
  end

  def normalize
    result = CONVERTERS.map { |canonical, type|
      [ canonical.to_sym, convert(type, field(canonical)) ]
    }.to_h
    result.merge(baths_pair)
  end

  private

  attr_reader :raw_data, :mappings

  def convert(type, value)
    return nil if value.blank?
    send(type, value)
  end

  def field(canonical)
    raw_name = mappings.fetch(canonical)
    raw_data[raw_name]
  end

  def passthrough(value) = value
  def integer(value)     = value.to_i
  def price_cents(value) = (value.gsub(/[$,]/, "").to_f * 100).to_i
  def date(value)        = Date.strptime(value, "%m/%d/%Y")
  def decimal(value)     = value.to_d

  def sq_ft(value)
    i = value.gsub(",", "").to_i
    i.zero? ? nil : i
  end

  def lot_size(value)
    cleaned = value.gsub(/Lot SqFt|,/, "").strip
    cleaned.empty? ? nil : cleaned.to_i
  end

  def baths_pair
    value = field("baths")
    return { full_baths: nil, half_baths: nil } if value.blank?
    full, half = value.split("|")
    { full_baths: full.to_i, half_baths: half&.to_i }
  end
end
