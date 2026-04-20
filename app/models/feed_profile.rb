class FeedProfile < ApplicationRecord
  has_many :feed_columns, dependent: :destroy
  has_many :raw_listings

  validates :name, presence: true
  validates :source_identifier, presence: true
end
