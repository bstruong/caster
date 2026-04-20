class Ingester
  def initialize(file_path, feed_profile)
    @file_path = file_path
    @feed_profile = feed_profile
  end

  def ingest!
    rows_ingested = 0

    CSV.foreach(@file_path, headers: true) do |row|
      RawListing.create!(
        feed_profile: @feed_profile,
        raw_data: row.to_h,
        source_file: @file_path,
        ingested_at: Time.current
      )
      rows_ingested += 1
    end

    Rails.logger.info("Ingested #{rows_ingested} rows from #{@file_path}")
    rows_ingested
  end
end
