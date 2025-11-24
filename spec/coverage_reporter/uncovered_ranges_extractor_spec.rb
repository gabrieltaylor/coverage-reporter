# frozen_string_literal: true

require "spec_helper"

RSpec.describe CoverageReporter::UncoveredRangesExtractor do
  context "when the coverage report is nil" do
    it "returns an empty hash" do
      parser = described_class.new(nil)
      expect(parser.call).to eq({})
    end
  end

  context "when the coverage report is not a Hash" do
    it "returns an empty hash" do
      parser = described_class.new(%w[array not hash])
      expect(parser.call).to eq({})
    end
  end

  context "when the coverage report has no 'coverage' key" do
    it "returns an empty hash" do
      parser = described_class.new({})
      expect(parser.call).to eq({})
    end
  end

  context "with SimpleCov format coverage data" do
    let(:coverage_report) do
      {
        "coverage" => {
          "lib/foo.rb"  => { "lines" => [nil, 1, 0, 2] }, # lines 2 & 4 covered, line 3 uncovered
          "lib/bar.rb"  => { "lines" => [1, 0, 1, 0, 3] }, # lines 1, 3, 5 covered, lines 2, 4 uncovered
          "lib/baz.rb"  => { "lines" => [nil, 0, 1, 1] }, # lines 3 & 4 covered, line 2 uncovered
          "lib/qux.rb"  => { "lines" => [0, 0, 5] }, # lines 1, 2 uncovered, line 3 covered
          "lib/quux.rb" => { "lines" => [1, 2, 0, 3] } # lines 1, 2, 4 covered, line 3 uncovered
        }
      }
    end

    it "parses coverage data and extracts uncovered ranges" do
      parser = described_class.new(coverage_report)
      result = parser.call

      expect(result.keys).to match_array(
        %w[
          lib/foo.rb
          lib/bar.rb
          lib/baz.rb
          lib/qux.rb
          lib/quux.rb
        ]
      )

      # lib/foo.rb: line 3 uncovered
      expect(result["lib/foo.rb"][:actual_ranges]).to contain_exactly([3, 3])
      expect(result["lib/foo.rb"][:display_ranges]).to contain_exactly([3, 3])
      # lib/bar.rb: lines 2, 4 uncovered
      expect(result["lib/bar.rb"][:actual_ranges]).to contain_exactly([2, 2], [4, 4])
      expect(result["lib/bar.rb"][:display_ranges]).to contain_exactly([2, 2], [4, 4])
      # lib/baz.rb: line 2 uncovered
      expect(result["lib/baz.rb"][:actual_ranges]).to contain_exactly([2, 2])
      expect(result["lib/baz.rb"][:display_ranges]).to contain_exactly([2, 2])
      # lib/qux.rb: lines 1, 2 uncovered
      expect(result["lib/qux.rb"][:actual_ranges]).to contain_exactly([1, 2])
      expect(result["lib/qux.rb"][:display_ranges]).to contain_exactly([1, 2])
      # lib/quux.rb: line 3 uncovered
      expect(result["lib/quux.rb"][:actual_ranges]).to contain_exactly([3, 3])
      expect(result["lib/quux.rb"][:display_ranges]).to contain_exactly([3, 3])
    end
  end

  context "with multiple files having different coverage patterns" do
    let(:coverage_report) do
      {
        "coverage" => {
          "lib/file1.rb" => { "lines" => [nil, 1, 0, 2] }, # lines 2 & 4 covered, line 3 uncovered
          "lib/file2.rb" => { "lines" => [0, 0, 1, 0, 1] }, # lines 3 & 5 covered, lines 1, 2, 4 uncovered
          "lib/file3.rb" => { "lines" => [1, 2, 0, 3, 0] } # lines 1, 2, 4 covered, lines 3, 5 uncovered
        }
      }
    end

    it "extracts uncovered ranges for each file" do
      parser = described_class.new(coverage_report)
      result = parser.call

      expect(result["lib/file1.rb"][:actual_ranges]).to contain_exactly([3, 3])
      expect(result["lib/file1.rb"][:display_ranges]).to contain_exactly([3, 3])
      expect(result["lib/file2.rb"][:actual_ranges]).to contain_exactly([1, 2], [4, 4])
      expect(result["lib/file2.rb"][:display_ranges]).to contain_exactly([1, 2], [4, 4])
      expect(result["lib/file3.rb"][:actual_ranges]).to contain_exactly([3, 3], [5, 5])
      expect(result["lib/file3.rb"][:display_ranges]).to contain_exactly([3, 3], [5, 5])
    end
  end

  context "when coverage data is empty or invalid" do
    let(:coverage_report) do
      {
        "coverage" => {}
      }
    end

    it "returns an empty hash" do
      parser = described_class.new(coverage_report)
      expect(parser.call).to eq({})
    end
  end

  context "with zero / nil / non-positive counts in coverage arrays" do
    let(:coverage_report) do
      {
        "coverage" => {
          "lib/mixed_counts.rb" => { "lines" => [0, nil, 1, 2, 0] }, # lines 3 & 4 covered, lines 1 & 5 uncovered
          "lib/zero_lines.rb"   => { "lines" => [0, 0, 0, 1, 0] } # lines 1, 2, 3, 5 uncovered, line 4 covered
        }
      }
    end

    it "identifies uncovered lines (count == 0) and ignores null/negative values" do
      parser = described_class.new(coverage_report)
      result = parser.call

      expect(result["lib/mixed_counts.rb"][:actual_ranges]).to contain_exactly([1, 1], [5, 5])
      # line 2 (nil) doesn't continue since followed by 1, not 0
      expect(result["lib/mixed_counts.rb"][:display_ranges]).to contain_exactly([1, 1], [5, 5])
      expect(result["lib/zero_lines.rb"][:actual_ranges]).to contain_exactly([1, 3], [5, 5])
      expect(result["lib/zero_lines.rb"][:display_ranges]).to contain_exactly([1, 3], [5, 5])
    end
  end

  context "range conversion logic" do
    it "converts consecutive uncovered lines into ranges" do
      coverage_report = {
        "coverage" => {
          "lib/consecutive.rb" => { "lines" => [0, 0, 0, 1, 0, 0, 0, 1, 0] } # lines 1,2,3,5,6,7,9 uncovered
        }
      }

      parser = described_class.new(coverage_report)
      result = parser.call

      expect(result["lib/consecutive.rb"][:actual_ranges]).to contain_exactly([1, 3], [5, 7], [9, 9])
      expect(result["lib/consecutive.rb"][:display_ranges]).to contain_exactly([1, 3], [5, 7], [9, 9])
    end

    it "handles single uncovered lines as single-element ranges" do
      coverage_report = {
        "coverage" => {
          "lib/single.rb" => { "lines" => [1, 0, 1, 0, 1] } # lines 2,4 uncovered
        }
      }

      parser = described_class.new(coverage_report)
      result = parser.call

      expect(result["lib/single.rb"][:actual_ranges]).to contain_exactly([2, 2], [4, 4])
      expect(result["lib/single.rb"][:display_ranges]).to contain_exactly([2, 2], [4, 4])
    end

    it "handles all lines uncovered as one range" do
      coverage_report = {
        "coverage" => {
          "lib/all_uncovered.rb" => { "lines" => [0, 0, 0, 0] } # lines 1,2,3,4 uncovered
        }
      }

      parser = described_class.new(coverage_report)
      result = parser.call

      expect(result["lib/all_uncovered.rb"][:actual_ranges]).to contain_exactly([1, 4])
      expect(result["lib/all_uncovered.rb"][:display_ranges]).to contain_exactly([1, 4])
    end

    it "handles no uncovered lines as empty array" do
      coverage_report = {
        "coverage" => {
          "lib/all_covered.rb" => { "lines" => [1, 2, 3, 4] } # all lines covered
        }
      }

      parser = described_class.new(coverage_report)
      result = parser.call

      expect(result["lib/all_covered.rb"][:actual_ranges]).to eq([])
      expect(result["lib/all_covered.rb"][:display_ranges]).to eq([])
    end

    it "handles mixed null and zero values correctly" do
      coverage_report = {
        "coverage" => {
          "lib/mixed.rb" => { "lines" => [nil, 0, nil, 0, 0, nil, 1] } # lines 2,4,5 uncovered, nil at line 3 continues range
        }
      }

      parser = described_class.new(coverage_report)
      result = parser.call

      # Actual ranges: only lines with 0 (lines 2, 4, 5)
      expect(result["lib/mixed.rb"][:actual_ranges]).to contain_exactly([2, 2], [4, 5])
      # Display ranges: includes nil at line 3 that continues the range
      expect(result["lib/mixed.rb"][:display_ranges]).to contain_exactly([2, 5])
    end

    it "handles empty coverage array" do
      coverage_report = {
        "coverage" => {
          "lib/empty.rb" => { "lines" => [] }
        }
      }

      parser = described_class.new(coverage_report)
      result = parser.call

      expect(result["lib/empty.rb"][:actual_ranges]).to eq([])
      expect(result["lib/empty.rb"][:display_ranges]).to eq([])
    end
  end

  context "with real coverage data from coverage.json" do
    let(:coverage_report) do
      JSON.parse(File.read(File.join(__dir__, "../fixtures/coverage2.json")))
    end

    it "extracts uncovered ranges from real coverage data" do
      parser = described_class.new(coverage_report)
      result = parser.call

      # Verify structure for all files
      result.each_value do |file_data|
        expect(file_data).to be_a(Hash)
        expect(file_data).to have_key(:actual_ranges)
        expect(file_data).to have_key(:display_ranges)
        expect(file_data[:actual_ranges]).to be_an(Array)
        expect(file_data[:display_ranges]).to be_an(Array)

        # Verify that display_ranges is at least as comprehensive as actual_ranges
        # (may include continuing nil lines that extend ranges)
        actual_total_lines = file_data[:actual_ranges].sum { |range| range[1] - range[0] + 1 }
        display_total_lines = file_data[:display_ranges].sum { |range| range[1] - range[0] + 1 }
        expect(display_total_lines).to be >= actual_total_lines
      end

      # Verify specific known files have expected structure
      expect(result["lib/coverage_reporter.rb"][:actual_ranges]).not_to be_empty
      expect(result["lib/coverage_reporter/cli.rb"][:actual_ranges]).to be_empty
      expect(result["lib/coverage_reporter/cli.rb"][:display_ranges]).to be_empty
    end
  end
end
