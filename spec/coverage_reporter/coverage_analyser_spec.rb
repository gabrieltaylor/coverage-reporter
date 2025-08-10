# frozen_string_literal: true

require "spec_helper"
require "coverage_reporter/coverage_analyser"

RSpec.describe CoverageReporter::CoverageAnalyser do
  describe "#call" do
    context "when diff is empty" do
      it "returns 100% coverage with zero totals" do
        analyser = described_class.new(coverage: {}, diff: {})
        result = analyser.call

        expect(result.total_changed).to eq(0)
        expect(result.total_covered).to eq(0)
        expect(result.diff_coverage).to eq(100.0)
        expect(result.uncovered_by_file).to be_empty
      end
    end

    context "when a file has nil lines in diff" do
      it "ignores that file" do
        coverage = { "lib/a.rb" => [1] }
        diff = { "lib/a.rb" => nil }

        result = described_class.new(coverage: coverage, diff: diff).call

        expect(result.total_changed).to eq(0)
        expect(result.total_covered).to eq(0)
        expect(result.diff_coverage).to eq(100.0)
        expect(result.uncovered_by_file).to be_empty
      end
    end

    context "with partial coverage in a single file" do
      it "computes metrics and lists uncovered lines" do
        coverage = { "lib/foo.rb" => [10, 12, 13] }
        diff = { "lib/foo.rb" => [10, 11, 12] }

        result = described_class.new(coverage: coverage, diff: diff).call

        expect(result.total_changed).to eq(3)
        expect(result.total_covered).to eq(2)
        expect(result.diff_coverage).to eq(66.67)
        expect(result.uncovered_by_file.keys).to contain_exactly("lib/foo.rb")
        expect(result.uncovered_by_file["lib/foo.rb"]).to contain_exactly(11)
      end
    end

    context "when coverage contains lines not in diff" do
      it "ignores extra covered lines" do
        coverage = { "lib/bar.rb" => [1, 2, 3, 4] }
        diff = { "lib/bar.rb" => [2, 3] }

        result = described_class.new(coverage: coverage, diff: diff).call

        expect(result.total_changed).to eq(2)
        expect(result.total_covered).to eq(2)
        expect(result.diff_coverage).to eq(100.0)
        expect(result.uncovered_by_file).to be_empty
      end
    end

    context "when the file in diff has no coverage entry" do
      it "treats all diff lines as uncovered" do
        coverage = {}
        diff = { "lib/missing.rb" => [5, 6, 7] }

        result = described_class.new(coverage: coverage, diff: diff).call

        expect(result.total_changed).to eq(3)
        expect(result.total_covered).to eq(0)
        expect(result.diff_coverage).to eq(0.0)
        expect(result.uncovered_by_file["lib/missing.rb"]).to contain_exactly(5, 6, 7)
      end
    end

    context "with multiple files and mixed coverage" do
      it "aggregates correctly and only lists files with misses" do
        coverage = {
          "app/models/user.rb"                  => [10, 11, 12, 15],
          "app/controllers/users_controller.rb" => [2, 3],
          "lib/util.rb"                         => [100]
        }
        diff = {
          "app/models/user.rb"                  => [10, 11, 13, 15],
          "app/controllers/users_controller.rb" => [1, 2, 3, 4],
          "lib/util.rb"                         => [],
          "lib/ignored.rb"                      => nil
        }

        # totals: user.rb 4 lines, controller 4 lines => 8 total
        # covered: user.rb intersect diff => [10,11,15] = 3
        # controller intersect => [2,3] = 2  => total covered 5
        # percent = 5/8 * 100 = 62.5
        result = described_class.new(coverage: coverage, diff: diff).call

        expect(result.total_changed).to eq(8)
        expect(result.total_covered).to eq(5)
        expect(result.diff_coverage).to eq(62.5)
        expect(result.uncovered_by_file.keys).to contain_exactly(
          "app/models/user.rb",
          "app/controllers/users_controller.rb"
        )
        expect(result.uncovered_by_file["app/models/user.rb"]).to contain_exactly(13)
        expect(result.uncovered_by_file["app/controllers/users_controller.rb"]).to contain_exactly(1, 4)
      end
    end

    context "when rounding coverage percentage" do
      it "rounds to two decimal places" do
        coverage = { "lib/round.rb" => [1] }
        diff = { "lib/round.rb" => [1, 2, 3] } # 1 / 3 = 33.3333 -> 33.33

        result = described_class.new(coverage: coverage, diff: diff).call

        expect(result.diff_coverage).to eq(33.33)
      end
    end
  end
end
