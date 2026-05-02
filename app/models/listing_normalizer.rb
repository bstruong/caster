class ListingNormalizer
  CONVERTERS = {
    "mls_number" => :string,
    "listing_status" => :string,
    "street_address" => :string,
    "city" => :string,
    "state" => :string,
    "zip_code" => :string,
    "mls_area_id" => :string,
    "mls_area_name" => :string,
    "property_type" => :string,
    "property_sub_type" => :string,
    "construction_type" => :string,
    "building_type" => :string,
    "parking_features" => :string,
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
    "lot_size_sqft" => :lot_size,
    "baths" => :baths
  }.freeze

  def initialize(raw_data, feed_profile)
    @raw_data = raw_data
    @mappings = feed_profile.feed_columns.pluck(:canonical_field_name, :raw_column_name).to_h
  end

  def normalize
    CONVERTERS.each_with_object({}) do |(canonical_name, type), result|
      result.merge!(convert(field(canonical_name), type, canonical_name))
    end
  end

  private

  def convert(value, type, name)
    case type
    when :string then convert_string(value, name)
    when :integer then convert_integer(value, name)
    when :price_cents then convert_price_cents(value, name)
    when :date then convert_date(value, name)
    when :decimal then convert_decimal(value, name)
    when :sq_ft then convert_sq_ft(value, name)
    when :lot_size then convert_lot_size(value, name)
    when :baths then convert_baths(value)
    end
  end

  def field(canonical_name)
    raw_name = @mappings.fetch(canonical_name)
    @raw_data[raw_name]
  end

  def convert_string(value, name)
    { name.to_sym => value.presence }
  end

  def convert_integer(value, name)
    { name.to_sym => value.blank? ? nil : value.to_i }
  end

  def convert_price_cents(value, name)
    return { name.to_sym => nil } if value.blank?
    { name.to_sym => (value.gsub(/[$,]/, "").to_f * 100).to_i }
  end

  def convert_date(value, name)
    return { name.to_sym => nil } if value.blank?
    { name.to_sym => Date.strptime(value, "%m/%d/%Y") }
  end

  def convert_decimal(value, name)
    { name.to_sym => value.blank? ? nil : value.to_d }
  end

  def convert_sq_ft(value, name)
    return { name.to_sym => nil } if value.blank?
    sq_ft = value.gsub(",", "").to_i
    { name.to_sym => (sq_ft.zero? ? nil : sq_ft) }
  end

  def convert_lot_size(value, name)
    return { name.to_sym => nil } if value.blank?
    cleaned = value.gsub(/Lot SqFt|,/, "").strip
    { name.to_sym => cleaned.empty? ? nil : cleaned.to_i }
  end

  def convert_baths(value)
    return { full_baths: nil, half_baths: nil } if value.blank?
    full, half = value.split("|")
    { full_baths: full.to_i, half_baths: half&.to_i }
  end
end
