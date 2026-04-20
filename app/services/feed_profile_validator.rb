class FeedProfileValidator
  class UnknownColumnsError < StandardError; end
  class MissingRequiredColumnsError < StandardError; end

  def initialize(headers, feed_profile)
    @headers = headers
    @feed_profile = feed_profile
  end

  def validate!
    check_for_unknown_columns!
    check_for_missing_required_columns!
  end

  private

  def check_for_unknown_columns!
    unknown = @headers - known_column_names
    raise UnknownColumnsError, "Unknown columns: #{unknown.join(', ')}" if unknown.any?
  end

  def check_for_missing_required_columns!
    missing = required_column_names - @headers
    raise MissingRequiredColumnsError, "Missing required columns: #{missing.join(', ')}" if missing.any?
  end

  def known_column_names
    @feed_profile.feed_columns.pluck(:raw_column_name)
  end

  def required_column_names
    @feed_profile.feed_columns.where(required: true).pluck(:raw_column_name)
  end
end
