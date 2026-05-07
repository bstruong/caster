require "rails_helper"

RSpec.describe Cents do
  describe ".to_dollars" do
    it "converts integer cents to dollars" do
      expect(Cents.to_dollars(123_34)).to eq(123.34)
    end

    # Proves the "nil at the edges" Sandi rule.
    it "returns nil for nil input" do
      expect(Cents.to_dollars(nil)).to be_nil
    end

    it "handles zero" do
      expect(Cents.to_dollars(0)).to eq(0.0)
    end
  end
end
