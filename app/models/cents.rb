module Cents
  def self.to_dollars(cents)
    return nil if cents.nil?

    (cents.to_f / 100).round(2)
  end

  def self.to_cents(dollars)
    return nil if dollars.nil?

    (dollars.gsub(/[$,]/, "").to_f * 100).to_i
  end
end
