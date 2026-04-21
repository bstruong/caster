class PriceTrendQuery
  def initialize(zip_code: nil, area_name: nil, status: "A")
    raise ArgumentError, "Provide zip_code or area_name, not both" if zip_code && area_name
    raise ArgumentError, "zip_code or area_name is required" if zip_code.nil? && area_name.nil?

    @zip_code = zip_code
    @area_name = area_name
    @status = status
  end

  def call
    scope
      .where("#{date_field} >= ?", 12.months.ago.beginning_of_month)
      .where.not(date_field => nil)
      .group(Arel.sql("DATE_TRUNC('month', #{date_field})"))
      .order(Arel.sql("DATE_TRUNC('month', #{date_field})"))
      .pluck(
        Arel.sql("DATE_TRUNC('month', #{date_field})"),
        Arel.sql("AVG(list_price_cents)"),
        Arel.sql("PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY list_price_cents)"),
        Arel.sql("AVG(sale_price_cents)"),
        Arel.sql("PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sale_price_cents)"),
        Arel.sql("AVG(days_on_market)"),
        Arel.sql("AVG(sale_price_cents::float / NULLIF(list_price_cents, 0))")
      )
      .map do |row|
        {
          month:                      row[0].strftime("%Y-%m"),
          average_list_price:         (row[1].to_f / 100).round(2),
          median_list_price:          (row[2].to_f / 100).round(2),
          average_sale_price:         row[3] ? (row[3].to_f / 100).round(2) : nil,
          median_sale_price:          row[4] ? (row[4].to_f / 100).round(2) : nil,
          average_days_on_market:     row[5].to_f.round(1),
          average_list_to_sale_ratio: row[6] ? row[6].to_f.round(4) : nil
        }
      end
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

  def date_field
    @status == "S" ? "closed_at" : "listed_at"
  end
end
