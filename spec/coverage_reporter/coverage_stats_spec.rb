# frozen_string_literal: true

require "spec_helper"
require "coverage_reporter/coverage_stats"

RSpec.describe CoverageReporter::CoverageStats do
  subject(:stats) { described_class.new(coverage_map, diff_map) }

  describe "#initialize" do
    context "when diff is empty" do
      let(:coverage_map) { {} }
      let(:diff_map) { {} }

      it "sets totals to zero, uncovered to empty hash, and diff_coverage to 100%" do
        expect(stats.total).to eq(0)
        expect(stats.covered).to eq(0)
        expect(stats.uncovered).to eq({})
        expect(stats.diff_coverage).to eq(100.0)
      end
    end

    context "with a single file and partial coverage" do
      let(:coverage_map) { { "lib/foo.rb" => [10, 12, 15] } }
      let(:diff_map) { { "lib/foo.rb" => [10, 11, 12, 13, 14, 15] } }

      it "computes total, covered, uncovered, and percentage correctly" do
        # Lines in diff: 6
        # Covered intersection: 10, 12, 15 (3)
        expect(stats.total).to eq(6)
        expect(stats.covered).to eq(3)
        expect(stats.uncovered).to eq("lib/foo.rb" => [11, 13, 14])
        expect(stats.diff_coverage).to eq(50.0)
      end
    end

    context "with multiple files and some fully covered" do
      let(:coverage_map) do
        {
          "app/models/user.rb"   => [3, 4, 5, 10],
          "app/services/doer.rb" => [20],
          "spec/irrelevant.rb"   => [1, 2, 3] # should be ignored (not in diff)
        }
      end
      let(:diff_map) do
        {
          "app/models/user.rb"   => [3, 4, 5, 6, 7, 10],
          "app/services/doer.rb" => [20],
          "README.md"            => [1, 2] # no coverage entries
        }
      end

      it "only considers files/lines present in diff and omits fully covered files from uncovered hash" do
        # user.rb: diff lines 6; covered intersection => 3,4,5,10 (4 covered, 2 missed)
        # doer.rb: diff lines 1; covered intersection => 20 (1 covered, 0 missed)
        # README.md: diff lines 2; covered intersection => none (0 covered, 2 missed)
        # Totals: total=6+1+2=9, covered=4+1+0=5, uncovered entries for user.rb + README.md
        expect(stats.total).to eq(9)
        expect(stats.covered).to eq(5)
        expect(stats.uncovered.keys).to contain_exactly("app/models/user.rb", "README.md")
        expect(stats.uncovered["app/models/user.rb"]).to contain_exactly(6, 7)
        expect(stats.uncovered["README.md"]).to contain_exactly(1, 2)
        expect(stats.diff_coverage).to eq((5 * 100.0 / 9).round(2))
      end
    end

    context "when no lines are covered in the diff" do
      let(:coverage_map) { { "lib/foo.rb" => [100] } } # not part of diff lines
      let(:diff_map) { { "lib/foo.rb" => [1, 2, 3] } }

      it "returns 0.0 diff coverage" do
        expect(stats.covered).to eq(0)
        expect(stats.total).to eq(3)
        expect(stats.diff_coverage).to eq(0.0)
      end
    end

    context "when rounding coverage percentage" do
      context "with 1 / 3 covered" do
        let(:coverage_map) { { "file.rb" => [2] } }
        let(:diff_map) { { "file.rb" => [1, 2, 3] } }

        it "rounds to two decimals (33.33)" do
          expect(stats.diff_coverage).to eq(33.33)
        end
      end

      context "with 2 / 3 covered" do
        let(:coverage_map) { { "file.rb" => [1, 3] } }
        let(:diff_map) { { "file.rb" => [1, 2, 3] } }

        it "rounds to two decimals (66.67)" do
          expect(stats.diff_coverage).to eq(66.67)
        end
      end
    end
  end

  describe "#diff_coverage" do
    context "when total is zero (no changed lines)" do
      let(:coverage_map) { { "file.rb" => [1, 2, 3] } }
      let(:diff_map) { {} }

      it "returns 100.0 (optimistic default for no diff)" do
        expect(stats.diff_coverage).to eq(100.0)
      end
    end
  end
end
