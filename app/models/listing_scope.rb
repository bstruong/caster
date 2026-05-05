class ListingScope
  attr_reader :status

  def initialize(zip_code: nil, area_name: nil, status: "A")
    raise ArgumentError, "Provide zip_code or area_name, not both" if zip_code && area_name
    raise ArgumentError, "zip_code or area_name is required" if zip_code.nil? && area_name.nil?

    @zip_code = zip_code
    @area_name = area_name
    @status = status
  end

  def to_relation
    listings = Listing.where(listing_status: @status)

    if @zip_code
      listings.where(zip_code: @zip_code)
    else
      listings.where(mls_area_name: @area_name)
    end
  end
end
