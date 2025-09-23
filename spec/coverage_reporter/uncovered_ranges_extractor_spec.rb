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
      expect(result["lib/foo.rb"]).to contain_exactly([3, 3])
      # lib/bar.rb: lines 2, 4 uncovered
      expect(result["lib/bar.rb"]).to contain_exactly([2, 2], [4, 4])
      # lib/baz.rb: line 2 uncovered
      expect(result["lib/baz.rb"]).to contain_exactly([2, 2])
      # lib/qux.rb: lines 1, 2 uncovered
      expect(result["lib/qux.rb"]).to contain_exactly([1, 2])
      # lib/quux.rb: line 3 uncovered
      expect(result["lib/quux.rb"]).to contain_exactly([3, 3])
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

      expect(result["lib/file1.rb"]).to contain_exactly([3, 3])
      expect(result["lib/file2.rb"]).to contain_exactly([1, 2], [4, 4])
      expect(result["lib/file3.rb"]).to contain_exactly([3, 3], [5, 5])
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

      expect(result["lib/mixed_counts.rb"]).to contain_exactly([1, 1], [5, 5])
      expect(result["lib/zero_lines.rb"]).to contain_exactly([1, 3], [5, 5])
    end
  end

  context "with absolute file paths in coverage data" do
    it "removes current working directory prefix from absolute paths" do
      # Use the actual current working directory in the test data
      current_dir = Dir.pwd
      coverage_report = {
        "coverage" => {
          "#{current_dir}/lib/absolute.rb" => { "lines" => [nil, 1, 0, 2] }, # lines 2 & 4 covered, line 3 uncovered
          "lib/relative.rb"                => { "lines" => [nil, 0, 1] }, # line 3 covered, line 2 uncovered
          "/some/other/path/outside.rb"    => { "lines" => [nil, 1] } # line 2 covered, but outside project
        }
      }

      parser = described_class.new(coverage_report)
      result = parser.call

      # Should remove current working directory prefix from absolute path
      expect(result["lib/absolute.rb"]).to contain_exactly([3, 3])
      # Should keep relative paths as-is
      expect(result["lib/relative.rb"]).to contain_exactly([2, 2])
      # Should keep paths that don't start with current working directory as-is
      expect(result["/some/other/path/outside.rb"]).to eq([])
    end
  end

  context "with various file path formats" do
    it "removes current working directory prefix when present, keeps others as-is" do
      # Use the actual current working directory in the test data
      current_dir = Dir.pwd
      coverage_report = {
        "coverage" => {
          "#{current_dir}/lib/absolute.rb" => { "lines" => [nil, 1, 0, 2] }, # Absolute path with current working directory
          "lib/relative.rb"                => { "lines" => [nil, 0, 1] }, # Relative path
          "/etc/passwd"                    => { "lines" => [nil, 1] }, # Absolute path outside current working directory
          "../sibling/file.rb"             => { "lines" => [nil, 1] }, # Relative path outside current working directory
          "app/models/user.rb"             => { "lines" => [nil, 1] } # Another relative path
        }
      }

      parser = described_class.new(coverage_report)
      result = parser.call

      # Should remove current working directory prefix from absolute path that starts with it
      expect(result["lib/absolute.rb"]).to contain_exactly([3, 3])
      # Should keep relative paths as-is
      expect(result["lib/relative.rb"]).to contain_exactly([2, 2])
      expect(result["app/models/user.rb"]).to eq([])
      # Should keep paths that don't start with current working directory as-is
      expect(result["/etc/passwd"]).to eq([])
      expect(result["../sibling/file.rb"]).to eq([])
    end
  end

  context "with paths that don't start with current working directory" do
    let(:coverage_report) do
      {
        "coverage" => {
          "/absolute/path/file.rb" => { "lines" => [nil, 1] },
          "relative/file.rb"       => { "lines" => [nil, 1] }
        }
      }
    end

    it "keeps original paths when they don't start with current working directory" do
      parser = described_class.new(coverage_report)
      result = parser.call

      # Should keep original paths when they don't start with current working directory
      expect(result.keys).to contain_exactly("/absolute/path/file.rb", "relative/file.rb")
      expect(result["/absolute/path/file.rb"]).to eq([])
      expect(result["relative/file.rb"]).to eq([])
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

      expect(result["lib/consecutive.rb"]).to contain_exactly([1, 3], [5, 7], [9, 9])
    end

    it "handles single uncovered lines as single-element ranges" do
      coverage_report = {
        "coverage" => {
          "lib/single.rb" => { "lines" => [1, 0, 1, 0, 1] } # lines 2,4 uncovered
        }
      }

      parser = described_class.new(coverage_report)
      result = parser.call

      expect(result["lib/single.rb"]).to contain_exactly([2, 2], [4, 4])
    end

    it "handles all lines uncovered as one range" do
      coverage_report = {
        "coverage" => {
          "lib/all_uncovered.rb" => { "lines" => [0, 0, 0, 0] } # lines 1,2,3,4 uncovered
        }
      }

      parser = described_class.new(coverage_report)
      result = parser.call

      expect(result["lib/all_uncovered.rb"]).to contain_exactly([1, 4])
    end

    it "handles no uncovered lines as empty array" do
      coverage_report = {
        "coverage" => {
          "lib/all_covered.rb" => { "lines" => [1, 2, 3, 4] } # all lines covered
        }
      }

      parser = described_class.new(coverage_report)
      result = parser.call

      expect(result["lib/all_covered.rb"]).to eq([])
    end

    it "handles mixed null and zero values correctly" do
      coverage_report = {
        "coverage" => {
          "lib/mixed.rb" => { "lines" => [nil, 0, nil, 0, 0, nil, 1] } # lines 2,4,5 uncovered
        }
      }

      parser = described_class.new(coverage_report)
      result = parser.call

      expect(result["lib/mixed.rb"]).to contain_exactly([2, 2], [4, 5])
    end

    it "handles empty coverage array" do
      coverage_report = {
        "coverage" => {
          "lib/empty.rb" => { "lines" => [] }
        }
      }

      parser = described_class.new(coverage_report)
      result = parser.call

      expect(result["lib/empty.rb"]).to eq([])
    end
  end
end
