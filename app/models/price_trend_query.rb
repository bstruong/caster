class PriceTrendQuery
  def initialize(zip_code: nil, area_name: nil, status: "A")
    @scope = ListingScope.new(zip_code: zip_code, area_name: area_name, status: status)
    @relation = @scope.to_relation
  end

  def call
    @relation
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
        .map do |month, avg_list, median_list, avg_sale, median_sale, avg_dom, list_to_sale|
          {
            month:                      month.strftime("%Y-%m"),
            average_list_price:         Cents.to_dollars(avg_list),
            median_list_price:          Cents.to_dollars(median_list),
            average_sale_price:         Cents.to_dollars(avg_sale),
            median_sale_price:          Cents.to_dollars(median_sale),
            average_days_on_market:     avg_dom.to_f.round(1),
            average_list_to_sale_ratio: list_to_sale ? list_to_sale.to_f.round(4) : nil
          }
        end
  end

  private

  def date_field
    @scope.status == "S" ? "closed_at" : "listed_at"
  end
end
