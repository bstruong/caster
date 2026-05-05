class MarketSummaryQuery
  def initialize(zip_code: nil, area_name: nil, status: "A")
    @scope = ListingScope.new(zip_code: zip_code, area_name: area_name, status: status)
    @relation = @scope.to_relation
  end

  def call
    count, avg_price, avg_dom, avg_ppsf = @relation.pick(
      Arel.sql("COUNT(*)"),
      Arel.sql("AVG(list_price_cents)"),
      Arel.sql("AVG(days_on_market)"),
      Arel.sql("AVG(list_price_cents::float / NULLIF(sq_ft_total, 0))")
    )

    {
      listings_count:         count.to_i,
      average_list_price:     Cents.to_dollars(avg_price),
      average_days_on_market: avg_dom.to_f.round(1),
      average_price_per_sqft: Cents.to_dollars(avg_ppsf),
      median_list_price:      median_list_price
    }
  end

  private

  def median_list_price
    count = @relation.count
    return nil if count.zero?

    mid = (count - 1) / 2
    cents = @relation.order(:list_price_cents).offset(mid).limit(1).pick(:list_price_cents)
    Cents.to_dollars(cents)
  end
end
