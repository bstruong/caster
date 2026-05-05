module Cents
  def self.to_dollars(cents)
    return nil if cents.nil?

    (cents.to_f / 100).round(2)
  end
end
