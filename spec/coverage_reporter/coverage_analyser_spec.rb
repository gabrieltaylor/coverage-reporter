# frozen_string_literal: true

require "spec_helper"
require "coverage_reporter/coverage_analyser"

RSpec.describe CoverageReporter::CoverageAnalyser do
  describe "#call" do
    context "when diff is empty" do
      it "returns empty uncovered map" do
        analyser = described_class.new(coverage: {}, diff: {})
        result = analyser.call

        expect(result).to be_empty
      end
    end

    context "when a file has nil ranges in diff" do
      it "ignores that file" do
        coverage = { "lib/a.rb" => [[1, 1]] }
        diff = { "lib/a.rb" => nil }

        result = described_class.new(coverage: coverage, diff: diff).call

        expect(result).to be_empty
      end
    end

    context "with partial coverage in a single file" do
      it "finds overlapping uncovered ranges" do
        coverage = { "lib/foo.rb" => [[10, 10], [12, 13]] }
        diff = { "lib/foo.rb" => [[10, 12]] }

        result = described_class.new(coverage: coverage, diff: diff).call

        expect(result.keys).to contain_exactly("lib/foo.rb")
        expect(result["lib/foo.rb"]).to eq([[10, 10], [12, 12]])
      end
    end

    context "when coverage contains ranges not in diff" do
      it "finds intersection of ranges" do
        coverage = { "lib/bar.rb" => [[1, 4]] }
        diff = { "lib/bar.rb" => [[2, 3]] }

        result = described_class.new(coverage: coverage, diff: diff).call

        expect(result["lib/bar.rb"]).to eq([[2, 3]])
      end
    end

    context "when the file in diff has no coverage entry" do
      it "skips the file entirely" do
        coverage = {}
        diff = { "lib/missing.rb" => [[5, 7]] }

        result = described_class.new(coverage: coverage, diff: diff).call

        expect(result).to be_empty
      end
    end

    context "with multiple files and mixed coverage" do
      it "finds overlapping uncovered ranges for each file" do
        coverage = {
          "app/models/user.rb"                  => [[10, 12], [15, 15]],
          "app/controllers/users_controller.rb" => [[2, 3]],
          "lib/util.rb"                         => [[100, 100]]
        }
        diff = {
          "app/models/user.rb"                  => [[10, 11], [13, 15]],
          "app/controllers/users_controller.rb" => [[1, 4]],
          "lib/util.rb"                         => [],
          "lib/ignored.rb"                      => nil
        }

        result = described_class.new(coverage: coverage, diff: diff).call

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
        coverage = { "lib/round.rb" => [[1, 1]] }
        diff = { "lib/round.rb" => [[1, 3]] }

        result = described_class.new(coverage: coverage, diff: diff).call

        expect(result["lib/round.rb"]).to eq([[1, 1]])
      end
    end
  end

  describe "#intersect_ranges" do
    it "finds overlapping ranges correctly" do
      analyser = described_class.new(coverage: {}, diff: {})
      
      changed = [[12, 14], [29, 30], [100, 120]]
      uncovered = [[1, 10], [14, 14], [30, 32], [110, 200]]
      
      result = analyser.send(:intersect_ranges, changed, uncovered)
      
      expect(result).to eq([[14, 14], [30, 30], [110, 120]])
    end

    it "handles empty ranges" do
      analyser = described_class.new(coverage: {}, diff: {})
      
      result = analyser.send(:intersect_ranges, [], [])
      
      expect(result).to eq([])
    end

    it "handles no overlapping ranges" do
      analyser = described_class.new(coverage: {}, diff: {})
      
      changed = [[1, 5]]
      uncovered = [[10, 15]]
      
      result = analyser.send(:intersect_ranges, changed, uncovered)
      
      expect(result).to eq([])
    end
  end
end
