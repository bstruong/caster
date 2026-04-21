class Ingester
  def initialize(file_path, feed_profile)
    @file_path = file_path
    @feed_profile = feed_profile
  end

  def ingest!
    raw_listings = []

    CSV.foreach(@file_path, headers: true) do |row|
      raw_listings << RawListing.create!(
        feed_profile: @feed_profile,
        raw_data:     row.to_h,
        source_file:  @file_path,
        ingested_at:  Time.current
      )
    end

    Rails.logger.info("Ingested #{raw_listings.count} rows from #{@file_path}")
    raw_listings
  end
end
