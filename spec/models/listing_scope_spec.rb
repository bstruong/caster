require "rails_helper"

RSpec.describe ListingScope do
  describe "#to_relation" do
    it "filters by zip code" do
      scope = ListingScope.new(zip_code: "94087", area_name: nil, status: "A")
      mls_numbers = scope.to_relation.pluck(:mls_number)
      expect(mls_numbers.size).to eq(5)
      expect(mls_numbers).not_to include("ML00000007") # cupertino_active_1
    end

    it "filters by area name" do
      scope = ListingScope.new(zip_code: nil, area_name: "Cupertino", status: "A")
      expect(scope.to_relation.pluck(:mls_number)).to eq(["ML00000007"])
    end

    it "filters by status" do
      scope = ListingScope.new(zip_code: "94087", area_name: nil, status: "S")
      expect(scope.to_relation.pluck(:mls_number).sort).to eq(%w[ML00000005 ML00000006])
    end
  end

  describe "construction" do
    it "raises when both zip and area provided" do
      expect {
        ListingScope.new(zip_code: "94087", area_name: "Sunnyvale", status: "A")
      }.to raise_error(ArgumentError, "Provide zip_code or area_name, not both")
    end

    it "raises when neither zip nor area provided" do
      expect {
        ListingScope.new(zip_code: nil, area_name: nil, status: "A")
      }.to raise_error(ArgumentError, "zip_code or area_name is required")
    end
  end

  describe "#status" do
    it "exposes the status value" do
      scope = ListingScope.new(zip_code: "94087", area_name: nil, status: "S")
      expect(scope.status).to eq("S")
    end
  end
end
