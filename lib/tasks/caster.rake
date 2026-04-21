require "csv"

namespace :caster do
  desc "Ingest a CSV file into raw_listings"
  task :ingest, [ :file_path ] => :environment do |_t, args|
    feed_profile = FeedProfile.first!
    ingester = Ingester.new(args[:file_path], feed_profile)
    ingester.ingest!
  end

  desc "Validate a CSV file against the feed profile without ingesting"
  task :validate, [ :file_path ] => :environment do |_t, args|
    feed_profile = FeedProfile.first!
    headers = CSV.read(args[:file_path], headers: true).headers
    FeedProfileValidator.new(feed_profile, headers).validate!
    puts "Validation passed."
  end

  desc "Run the full pipeline for a CSV file"
  task :run, [ :file_path ] => :environment do |_t, args|
    feed_profile = FeedProfile.first!

    headers = CSV.read(args[:file_path], headers: true).headers
    FeedProfileValidator.new(feed_profile, headers).validate!
    puts "Validation passed."

    ingester = Ingester.new(args[:file_path], feed_profile)
    raw_listings = ingester.ingest!
    puts "Ingested #{raw_listings.count} rows."

    raw_listings.each do |raw_listing|
      Normalizer.new(raw_listing, feed_profile).normalize!
    end
    puts "Normalization complete."
  end
end
