# frozen_string_literal: true

require "spec_helper"

RSpec.describe CoverageReporter::ModifiedUncoveredIntersection do
  describe "#call" do
    context "when the ranges are empty" do
      it "returns empty uncovered map" do
        analyser = described_class.new(uncovered_ranges: {}, modified_ranges: {})
        result = analyser.call

        expect(result).to be_empty
      end
    end

    context "with partial coverage in a single file" do
      it "finds overlapping uncovered ranges" do
        uncovered_ranges = { "lib/foo.rb" => [[10, 10], [12, 13]] }
        modified_ranges = { "lib/foo.rb" => [[10, 12]] }

        result = described_class.new(uncovered_ranges:, modified_ranges:).call

        expect(result.keys).to contain_exactly("lib/foo.rb")
        expect(result["lib/foo.rb"]).to eq([[10, 10], [12, 12]])
      end
    end

    context "when coverage contains ranges not in diff" do
      it "finds intersection of ranges" do
        uncovered_ranges = { "lib/bar.rb" => [[1, 4]] }
        modified_ranges = { "lib/bar.rb" => [[2, 3]] }

        result = described_class.new(uncovered_ranges:, modified_ranges:).call

        expect(result["lib/bar.rb"]).to eq([[2, 3]])
      end
    end

    context "when the file in diff has no coverage entry" do
      it "skips the file entirely" do
        uncovered_ranges = {}
        modified_ranges = { "lib/missing.rb" => [[5, 7]] }

        result = described_class.new(uncovered_ranges:, modified_ranges:).call

        expect(result).to be_empty
      end
    end

    context "with multiple files and mixed coverage" do
      it "finds overlapping uncovered ranges for each file" do
        uncovered_ranges = {
          "app/models/user.rb"                  => [[10, 12], [15, 15]],
          "app/controllers/users_controller.rb" => [[2, 3]],
          "lib/util.rb"                         => [[100, 100]]
        }
        modified_ranges = {
          "app/models/user.rb"                  => [[10, 11], [13, 15]],
          "app/controllers/users_controller.rb" => [[1, 4]],
          "lib/util.rb"                         => [],
          "lib/ignored.rb"                      => nil
        }

        result = described_class.new(uncovered_ranges:, modified_ranges:).call

        expect(result.keys).to contain_exactly(
          "app/models/user.rb",
          "app/controllers/users_controller.rb",
          "lib/util.rb"
        )
        expect(result["app/models/user.rb"]).to eq([[10, 11], [15, 15]])
        expect(result["app/controllers/users_controller.rb"]).to eq([[2, 3]])
        expect(result["lib/util.rb"]).to eq([])
      end
    end

    context "with range intersections" do
      it "finds correct overlapping ranges" do
        uncovered_ranges = { "lib/round.rb" => [[1, 1]] }
        modified_ranges = { "lib/round.rb" => [[1, 3]] }

        result = described_class.new(uncovered_ranges:, modified_ranges:).call

        expect(result["lib/round.rb"]).to eq([[1, 1]])
      end
    end
  end
end
