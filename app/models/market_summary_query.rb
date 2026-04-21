class MarketSummaryQuery
  def initialize(zip_code: nil, area_name: nil, status: "A")
    raise ArgumentError, "Provide zip_code or area_name, not both" if zip_code && area_name
    raise ArgumentError, "zip_code or area_name is required" if zip_code.nil? && area_name.nil?

    @zip_code = zip_code
    @area_name = area_name
    @status = status
  end

  def call
    results = scope.pick(
      Arel.sql("COUNT(*)"),
      Arel.sql("AVG(list_price_cents)"),
      Arel.sql("AVG(days_on_market)"),
      Arel.sql("AVG(list_price_cents::float / NULLIF(sq_ft_total, 0))")
    )

    {
      listings_count:         results[0].to_i,
      average_list_price:     (results[1].to_f / 100).round(2),
      average_days_on_market: results[2].to_f.round(1),
      average_price_per_sqft: (results[3].to_f / 100).round(2),
      median_list_price:      median_list_price
    }
  end

  private

  def scope
    listings = Listing.where(listing_status: @status)

    if @zip_code
      listings.where(zip_code: @zip_code)
    else
      listings.where(mls_area_name: @area_name)
    end
  end

  def median_list_price
    count = scope.count
    return nil if count.zero?

    mid = (count - 1) / 2
    cents = scope.order(:list_price_cents).offset(mid).limit(1).pick(:list_price_cents)
    (cents.to_f / 100).round(2)
  end
end
