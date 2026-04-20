class FeedColumn < ApplicationRecord
  belongs_to :feed_profile

  validates :raw_column_name, presence: true
  validates :canonical_field_name, presence: true
end
