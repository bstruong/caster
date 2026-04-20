namespace :caster do
  desc "Ingest a CSV file into raw_listings"
  task :ingest, [:file_path] => :environment do |_t, args|
    feed_profile = FeedProfile.first!
    ingester = Ingester.new(args[:file_path], feed_profile)
    ingester.ingest!
  end
end
