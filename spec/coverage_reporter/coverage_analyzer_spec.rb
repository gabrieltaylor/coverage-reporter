# frozen_string_literal: true

require "spec_helper"

RSpec.describe CoverageReporter::CoverageAnalyzer do
  describe "#call" do
    context "when the ranges are empty" do
      it "returns empty intersections and 100% coverage" do
        analyzer = described_class.new(coverage_ranges: {}, modified_ranges: {})
        result = analyzer.call

        expect(result[:intersections]).to be_empty
        expect(result[:coverage_stats][:total_modified_lines]).to eq(0)
        expect(result[:coverage_stats][:uncovered_modified_lines]).to eq(0)
        expect(result[:coverage_stats][:covered_modified_lines]).to eq(0)
        expect(result[:coverage_stats][:coverage_percentage]).to eq(100.0)
      end
    end

    context "with perfect coverage in a single file" do
      it "returns empty intersections and 100% coverage" do
        # File is in coverage data with empty array (all lines covered)
        coverage_ranges = { "lib/foo.rb" => { actual_ranges: [], display_ranges: [], relevant_ranges: [[10, 12]] } }
        modified_ranges = { "lib/foo.rb" => [[10, 12]] }

        result = described_class.new(coverage_ranges:, modified_ranges:).call

        expect(result[:intersections]).to be_empty
        expect(result[:coverage_stats][:total_modified_lines]).to eq(3)
        expect(result[:coverage_stats][:uncovered_modified_lines]).to eq(0)
        expect(result[:coverage_stats][:covered_modified_lines]).to eq(3)
        expect(result[:coverage_stats][:coverage_percentage]).to eq(100.0)
      end
    end

    context "with partial coverage in a single file" do
      it "returns correct intersections and coverage percentage" do
        coverage_ranges = {
          "lib/foo.rb" => {
            actual_ranges:   [[10, 10], [12, 13]],
            display_ranges:  [[10, 10], [12, 13]],
            relevant_ranges: [[10, 13]]
          }
        }
        modified_ranges = { "lib/foo.rb" => [[10, 12]] }

        result = described_class.new(coverage_ranges:, modified_ranges:).call

        expect(result[:intersections]["lib/foo.rb"]).to eq([[10, 10], [12, 12]])
        expect(result[:coverage_stats][:total_modified_lines]).to eq(3)
        expect(result[:coverage_stats][:uncovered_modified_lines]).to eq(2) # lines 10 and 12
        expect(result[:coverage_stats][:covered_modified_lines]).to eq(1) # line 11
        expect(result[:coverage_stats][:coverage_percentage]).to eq(33.33)
      end
    end

    context "with no coverage in a single file" do
      it "returns all modified lines as intersections and 0% coverage" do
        coverage_ranges = { "lib/foo.rb" => { actual_ranges: [[10, 12]], display_ranges: [[10, 12]], relevant_ranges: [[10, 12]] } }
        modified_ranges = { "lib/foo.rb" => [[10, 12]] }

        result = described_class.new(coverage_ranges:, modified_ranges:).call

        expect(result[:intersections]["lib/foo.rb"]).to eq([[10, 12]])
        expect(result[:coverage_stats][:total_modified_lines]).to eq(3)
        expect(result[:coverage_stats][:uncovered_modified_lines]).to eq(3)
        expect(result[:coverage_stats][:covered_modified_lines]).to eq(0)
        expect(result[:coverage_stats][:coverage_percentage]).to eq(0.0)
      end
    end

    context "when coverage contains ranges not in diff" do
      it "ignores uncovered ranges outside modified ranges" do
        coverage_ranges = {
          "lib/bar.rb" => {
            actual_ranges:   [[1, 4], [20, 25]],
            display_ranges:  [[1, 4], [20, 25]],
            relevant_ranges: [[2, 3]]
          }
        }
        modified_ranges = { "lib/bar.rb" => [[2, 3]] }

        result = described_class.new(coverage_ranges:, modified_ranges:).call

        expect(result[:intersections]["lib/bar.rb"]).to eq([[2, 3]])
        expect(result[:coverage_stats][:total_modified_lines]).to eq(2)
        expect(result[:coverage_stats][:uncovered_modified_lines]).to eq(2) # lines 2 and 3
        expect(result[:coverage_stats][:covered_modified_lines]).to eq(0)
        expect(result[:coverage_stats][:coverage_percentage]).to eq(0.0)
      end
    end

    context "when the file in diff has no coverage entry" do
      it "excludes the file from coverage calculation and returns empty intersections" do
        coverage_ranges = {}
        modified_ranges = { "lib/missing.rb" => [[5, 7]] }

        result = described_class.new(coverage_ranges:, modified_ranges:).call

        expect(result[:intersections]).to be_empty
        expect(result[:coverage_stats][:total_modified_lines]).to eq(0)
        expect(result[:coverage_stats][:uncovered_modified_lines]).to eq(0)
        expect(result[:coverage_stats][:covered_modified_lines]).to eq(0)
        expect(result[:coverage_stats][:coverage_percentage]).to eq(100.0)
      end
    end

    context "when the modified lines are a subset of the uncovered lines" do
      it "returns the correct coverage stats" do
        coverage_ranges = {
          "lib/foo.rb" => {
            actual_ranges:   [[1, 2], [4, 4], [10, 13]],
            display_ranges:  [[1, 4], [10, 13]],
            relevant_ranges: [[1, 2], [4, 4], [10, 13], [20, 25]]
          }
        }
        modified_ranges = { "lib/foo.rb" => [[10, 12], [20, 25]], "lib/bar.rb" => [[1, 2]] }

        result = described_class.new(coverage_ranges:, modified_ranges:).call

        expect(result[:intersections]["lib/foo.rb"]).to eq([[10, 12]])
        expect(result[:coverage_stats][:total_modified_lines]).to eq(9)
        expect(result[:coverage_stats][:uncovered_modified_lines]).to eq(3)
        expect(result[:coverage_stats][:covered_modified_lines]).to eq(6)
        expect(result[:coverage_stats][:coverage_percentage]).to eq(66.67)
      end
    end

    context "when the display ranges are larger than the actual ranges" do
      it "returns the uncovered lines as intersections and correct coverage" do
        coverage_ranges = {
          "lib/foo.rb" => {
            actual_ranges:   [[1, 2], [4, 4], [10, 11], [13, 14]],
            display_ranges:  [[1, 4], [10, 14]],
            relevant_ranges: [[1, 15]]
          }
        }
        modified_ranges = { "lib/foo.rb" => [[9, 15]], "lib/bar.rb" => [[1, 2]] }

        result = described_class.new(coverage_ranges:, modified_ranges:).call

        expect(result[:intersections]["lib/foo.rb"]).to eq([[10, 14]])
        expect(result[:coverage_stats][:total_modified_lines]).to eq(7)
        # Modified: lines 9-15 (7 lines)
        # Uncovered: lines 10-11 (2 lines) + lines 13-14 (2 lines) = 4 uncovered
        # Covered: 7 - 4 = 3 lines = 42.86% coverage
        expect(result[:coverage_stats][:uncovered_modified_lines]).to eq(4)
        expect(result[:coverage_stats][:covered_modified_lines]).to eq(3)
        expect(result[:coverage_stats][:coverage_percentage]).to eq(42.86)
      end
    end

    context "with multiple files and mixed coverage" do
      it "calculates overall coverage and intersections for each file" do
        coverage_ranges = {
          "app/models/user.rb"                  => {
            actual_ranges:   [[10, 12], [15, 15]],
            display_ranges:  [[10, 12], [15, 15]],
            relevant_ranges: [[1, 12], [15, 15]]
          },
          "app/controllers/users_controller.rb" => { actual_ranges: [[2, 3]], display_ranges: [[2, 3]], relevant_ranges: [[1, 4]] },
          "lib/util.rb"                         => {
            actual_ranges:   [[100, 100]],
            display_ranges:  [[100, 100]],
            relevant_ranges: [[100, 100]]
          }
        }
        modified_ranges = {
          "app/models/user.rb"                  => [[10, 11], [13, 15]],
          "app/controllers/users_controller.rb" => [[1, 4]],
          "lib/util.rb"                         => [[100, 100]],
          "lib/ignored.rb"                      => nil
        }

        result = described_class.new(coverage_ranges:, modified_ranges:).call

        # Check intersections
        expect(result[:intersections].keys).to contain_exactly(
          "app/models/user.rb",
          "app/controllers/users_controller.rb",
          "lib/util.rb"
        )
        expect(result[:intersections]["app/models/user.rb"]).to eq([[10, 11], [15, 15]])
        expect(result[:intersections]["app/controllers/users_controller.rb"]).to eq([[2, 3]])
        expect(result[:intersections]["lib/util.rb"]).to eq([[100, 100]])

        # Check coverage stats
        # app/models/user.rb: lines 10-11 (2 lines), 13-15 (3 lines) = 5 total
        #   uncovered: lines 10-11 (2 lines) + line 15 (1 line) = 3 uncovered
        # app/controllers/users_controller.rb: lines 1-4 (4 lines)
        #   uncovered: lines 2-3 (2 lines) = 2 uncovered
        # lib/util.rb: line 100 (1 line)
        #   uncovered: line 100 (1 line) = 1 uncovered
        # Total: 10 lines, 6 uncovered, 4 covered = 40% coverage

        expect(result[:coverage_stats][:total_modified_lines]).to eq(8)
        expect(result[:coverage_stats][:uncovered_modified_lines]).to eq(6)
        expect(result[:coverage_stats][:covered_modified_lines]).to eq(2)
        expect(result[:coverage_stats][:coverage_percentage]).to eq(25.0)
      end
    end

    context "with range intersections" do
      it "finds correct overlapping ranges and calculates coverage" do
        coverage_ranges = {
          "lib/round.rb" => {
            actual_ranges:   [[1, 1], [5, 8]],
            display_ranges:  [[1, 1], [5, 8]],
            relevant_ranges: [[1, 3], [6, 10]]
          }
        }
        modified_ranges = { "lib/round.rb" => [[1, 3], [6, 10]] }

        result = described_class.new(coverage_ranges:, modified_ranges:).call

        expect(result[:intersections]["lib/round.rb"]).to eq([[1, 1], [6, 8]])
        # Modified: lines 1-3 (3 lines) + lines 6-10 (5 lines) = 8 total
        # Uncovered: line 1 (1 line) + lines 6-8 (3 lines) = 4 uncovered
        # Covered: 8 - 4 = 4 lines = 50% coverage
        expect(result[:coverage_stats][:total_modified_lines]).to eq(8)
        expect(result[:coverage_stats][:uncovered_modified_lines]).to eq(4)
        expect(result[:coverage_stats][:covered_modified_lines]).to eq(4)
        expect(result[:coverage_stats][:coverage_percentage]).to eq(50.0)
      end
    end

    context "with empty modified ranges" do
      it "handles empty arrays correctly" do
        coverage_ranges = { "lib/empty.rb" => { actual_ranges: [[1, 5]], display_ranges: [[1, 5]] } }
        modified_ranges = { "lib/empty.rb" => [] }

        result = described_class.new(coverage_ranges:, modified_ranges:).call

        expect(result[:intersections]).to be_empty
        expect(result[:coverage_stats][:total_modified_lines]).to eq(0)
        expect(result[:coverage_stats][:uncovered_modified_lines]).to eq(0)
        expect(result[:coverage_stats][:covered_modified_lines]).to eq(0)
        expect(result[:coverage_stats][:coverage_percentage]).to eq(100.0)
      end
    end

    context "with nil modified ranges" do
      it "handles nil values correctly" do
        coverage_ranges = { "lib/nil.rb" => { actual_ranges: [[1, 5]], display_ranges: [[1, 5]] } }
        modified_ranges = { "lib/nil.rb" => nil }

        result = described_class.new(coverage_ranges:, modified_ranges:).call

        expect(result[:intersections]).to be_empty
        expect(result[:coverage_stats][:total_modified_lines]).to eq(0)
        expect(result[:coverage_stats][:uncovered_modified_lines]).to eq(0)
        expect(result[:coverage_stats][:covered_modified_lines]).to eq(0)
        expect(result[:coverage_stats][:coverage_percentage]).to eq(100.0)
      end
    end

    context "with complex overlapping ranges" do
      it "handles complex intersections correctly" do
        coverage_ranges = {
          "lib/complex.rb" => {
            actual_ranges:   [[1, 10], [15, 20], [25, 30]],
            display_ranges:  [[1, 10], [15, 20], [25, 30]],
            relevant_ranges: [[5, 18], [22, 35]]
          }
        }
        modified_ranges = { "lib/complex.rb" => [[5, 18], [22, 35]] }

        result = described_class.new(coverage_ranges:, modified_ranges:).call

        expect(result[:intersections]["lib/complex.rb"]).to eq([[5, 10], [15, 18], [25, 30]])
        # Modified: lines 5-18 (14 lines) + lines 22-35 (14 lines) = 28 total
        # Uncovered: lines 5-10 (6 lines) + lines 15-18 (4 lines) + lines 25-30 (6 lines) = 16 uncovered
        # Covered: 28 - 16 = 12 lines = 42.86% coverage
        expect(result[:coverage_stats][:total_modified_lines]).to eq(28)
        expect(result[:coverage_stats][:uncovered_modified_lines]).to eq(16)
        expect(result[:coverage_stats][:covered_modified_lines]).to eq(12)
        expect(result[:coverage_stats][:coverage_percentage]).to eq(42.86)
      end
    end

    context "with real project data from uncovered.txt and modified.txt" do
      it "processes actual coverage and diff data correctly" do
        # Load real data from the project files
        uncovered_data = File.read(File.join(__dir__, "../fixtures/uncovered.txt")).strip
        modified_data = File.read(File.join(__dir__, "../fixtures/modified.txt")).strip

        # Parse the hash data from the files and convert to new structure
        coverage_ranges_old = eval(uncovered_data) # rubocop:disable Security/Eval
        modified_ranges = eval(modified_data) # rubocop:disable Security/Eval
        coverage_ranges = coverage_ranges_old.transform_values do |ranges|
          { actual_ranges: ranges, display_ranges: ranges }
        end
        # Add relevant_ranges based on modified_ranges for each file
        coverage_ranges.each_key do |file|
          coverage_ranges[file][:relevant_ranges] = modified_ranges[file] || []
        end

        result = described_class.new(coverage_ranges:, modified_ranges:).call

        expected = {
          intersections:  {
            "lib/coverage_reporter/coverage_analyzer.rb"            => [[72, 72], [74, 74]],
            "spec/coverage_reporter/coverage_report_loader_spec.rb" => [[43, 43], [45, 45], [52, 52]]
          },
          coverage_stats: {
            total_modified_lines:     587,
            uncovered_modified_lines: 5,
            covered_modified_lines:   582,
            coverage_percentage:      99.15
          }
        }

        expect(result).to eq(expected)
      end
    end
  end
end
