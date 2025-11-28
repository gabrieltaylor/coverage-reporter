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

      # lib/foo.rb: line 3 uncovered, lines 2,3,4 relevant (nil, 1, 0, 2)
      expect(result["lib/foo.rb"][:actual_ranges]).to contain_exactly([3, 3])
      expect(result["lib/foo.rb"][:display_ranges]).to contain_exactly([3, 3])
      expect(result["lib/foo.rb"][:relevant_ranges]).to contain_exactly([2, 4])
      # lib/bar.rb: lines 2, 4 uncovered, all lines relevant (1, 0, 1, 0, 3)
      expect(result["lib/bar.rb"][:actual_ranges]).to contain_exactly([2, 2], [4, 4])
      expect(result["lib/bar.rb"][:display_ranges]).to contain_exactly([2, 2], [4, 4])
      expect(result["lib/bar.rb"][:relevant_ranges]).to contain_exactly([1, 5])
      # lib/baz.rb: line 2 uncovered, lines 2,3,4 relevant (nil, 0, 1, 1)
      expect(result["lib/baz.rb"][:actual_ranges]).to contain_exactly([2, 2])
      expect(result["lib/baz.rb"][:display_ranges]).to contain_exactly([2, 2])
      expect(result["lib/baz.rb"][:relevant_ranges]).to contain_exactly([2, 4])
      # lib/qux.rb: lines 1, 2 uncovered, all lines relevant (0, 0, 5)
      expect(result["lib/qux.rb"][:actual_ranges]).to contain_exactly([1, 2])
      expect(result["lib/qux.rb"][:display_ranges]).to contain_exactly([1, 2])
      expect(result["lib/qux.rb"][:relevant_ranges]).to contain_exactly([1, 3])
      # lib/quux.rb: line 3 uncovered, all lines relevant (1, 2, 0, 3)
      expect(result["lib/quux.rb"][:actual_ranges]).to contain_exactly([3, 3])
      expect(result["lib/quux.rb"][:display_ranges]).to contain_exactly([3, 3])
      expect(result["lib/quux.rb"][:relevant_ranges]).to contain_exactly([1, 4])
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
      expect(result["lib/file1.rb"][:relevant_ranges]).to contain_exactly([2, 4])
      expect(result["lib/file2.rb"][:actual_ranges]).to contain_exactly([1, 2], [4, 4])
      expect(result["lib/file2.rb"][:display_ranges]).to contain_exactly([1, 2], [4, 4])
      expect(result["lib/file2.rb"][:relevant_ranges]).to contain_exactly([1, 5])
      expect(result["lib/file3.rb"][:actual_ranges]).to contain_exactly([3, 3], [5, 5])
      expect(result["lib/file3.rb"][:display_ranges]).to contain_exactly([3, 3], [5, 5])
      expect(result["lib/file3.rb"][:relevant_ranges]).to contain_exactly([1, 5])
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
      # relevant lines: 1, 3, 4, 5 (0, nil, 1, 2, 0)
      expect(result["lib/mixed_counts.rb"][:relevant_ranges]).to contain_exactly([1, 1], [3, 5])
      expect(result["lib/zero_lines.rb"][:actual_ranges]).to contain_exactly([1, 3], [5, 5])
      expect(result["lib/zero_lines.rb"][:display_ranges]).to contain_exactly([1, 3], [5, 5])
      # relevant lines: 1, 2, 3, 4, 5 (0, 0, 0, 1, 0)
      expect(result["lib/zero_lines.rb"][:relevant_ranges]).to contain_exactly([1, 5])
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
      # relevant lines: all lines (0, 0, 0, 1, 0, 0, 0, 1, 0)
      expect(result["lib/consecutive.rb"][:relevant_ranges]).to contain_exactly([1, 9])
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
      # relevant lines: all lines (1, 0, 1, 0, 1)
      expect(result["lib/single.rb"][:relevant_ranges]).to contain_exactly([1, 5])
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
      # relevant lines: all lines (0, 0, 0, 0)
      expect(result["lib/all_uncovered.rb"][:relevant_ranges]).to contain_exactly([1, 4])
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
      # relevant lines: all lines (1, 2, 3, 4)
      expect(result["lib/all_covered.rb"][:relevant_ranges]).to contain_exactly([1, 4])
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
      # relevant lines: 2, 4, 5, 7 (nil, 0, nil, 0, 0, nil, 1)
      expect(result["lib/mixed.rb"][:relevant_ranges]).to contain_exactly([2, 2], [4, 5], [7, 7])
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
      expect(result["lib/empty.rb"][:relevant_ranges]).to eq([])
    end
  end

  context "with real coverage data from coverage.json" do
    let(:coverage_report) do
      JSON.parse(File.read(File.join(__dir__, "../fixtures/coverage2.json")))
    end

    it "extracts uncovered ranges from real coverage data" do
      parser = described_class.new(coverage_report)
      result = parser.call

      expected_result = {
        "lib/coverage_reporter.rb"                                  => {
          actual_ranges:   [[29, 30], [32, 32]],
          display_ranges:  [[29, 32]],
          relevant_ranges: [[3, 4], [6, 6], [8, 9], [11, 12], [14, 15], [17, 20], [24, 24], [26, 27], [29, 30], [32, 32], [36, 48]]
        },
        "lib/coverage_reporter/cli.rb"                              => { actual_ranges: [], display_ranges: [], relevant_ranges: [[3, 7]] },
        "lib/coverage_reporter/coverage_analyzer.rb"                => {
          actual_ranges:   [[72, 72], [74, 74]],
          display_ranges:  [[72, 74]],
          relevant_ranges: [
            [3, 3],
            [16, 19],
            [22, 23],
            [25, 27],
            [29, 30],
            [32, 35],
            [38, 38],
            [40, 40],
            [42, 42],
            [45, 45],
            [47, 48],
            [51, 51],
            [53, 54],
            [57, 58],
            [60, 60],
            [62, 62],
            [65, 65],
            [71, 72],
            [74, 74],
            [77, 79],
            [85, 85],
            [87, 87],
            [97, 98],
            [101, 102],
            [104, 105],
            [107, 109],
            [112, 113],
            [115, 115],
            [118, 119],
            [121, 121],
            [125, 125],
            [129, 137],
            [139, 139],
            [142, 142],
            [146, 147],
            [149, 150]
          ]
        },
        "lib/coverage_reporter/coverage_report_loader.rb"           => {
          actual_ranges:   [[23, 23]],
          display_ranges:  [[23, 23]],
          relevant_ranges: [
            [3, 3],
            [5, 5],
            [7, 10],
            [12, 14],
            [17, 19],
            [21, 21],
            [23, 23],
            [25, 25],
            [27, 27],
            [30, 30],
            [32, 32],
            [34, 35],
            [38, 39]
          ]
        },
        "lib/coverage_reporter/global_comment.rb"                   => {
          actual_ranges:   [],
          display_ranges:  [],
          relevant_ranges: [[3, 9], [12, 12], [14, 14], [16, 17], [21, 21]]
        },
        "lib/coverage_reporter/global_comment_poster.rb"            => {
          actual_ranges:   [],
          display_ranges:  [],
          relevant_ranges: [[3, 7], [10, 11], [14, 14], [16, 16], [18, 20], [22, 23], [25, 25]]
        },
        "lib/coverage_reporter/inline_comment.rb"                   => {
          actual_ranges:   [],
          display_ranges:  [],
          relevant_ranges: [[3, 5], [7, 11], [14, 15], [18, 19]]
        },
        "lib/coverage_reporter/inline_comment_factory.rb"           => {
          actual_ranges:   [],
          display_ranges:  [],
          relevant_ranges: [[3, 7], [10, 11], [13, 15], [17, 17], [26, 26], [29, 29], [31, 31], [33, 35], [38, 40], [42, 42]]
        },
        "lib/coverage_reporter/inline_comment_poster.rb"            => {
          actual_ranges:   [],
          display_ranges:  [],
          relevant_ranges: [
            [3, 3],
            [5, 12],
            [15, 16],
            [18, 20],
            [23, 23],
            [26, 26],
            [28, 28],
            [30, 31],
            [34, 36],
            [38, 38],
            [40, 41],
            [45, 46],
            [48, 49],
            [51, 53],
            [56, 56],
            [60, 61],
            [64, 65],
            [67, 69],
            [71, 71],
            [81, 83]
          ]
        },
        "lib/coverage_reporter/modified_ranges_extractor.rb"        => {
          actual_ranges:   [],
          display_ranges:  [],
          relevant_ranges: [
            [3, 5],
            [7, 8],
            [11, 12],
            [14, 14],
            [16, 16],
            [19, 19],
            [21, 24],
            [26, 27],
            [29, 31],
            [34, 36],
            [39, 39],
            [41, 41],
            [45, 45],
            [48, 49],
            [52, 53],
            [56, 57],
            [59, 59],
            [61, 61],
            [63, 63],
            [67, 68],
            [70, 71],
            [74, 75],
            [77, 78],
            [82, 83],
            [85, 87],
            [89, 90],
            [92, 92],
            [95, 97],
            [102, 103]
          ]
        },
        "lib/coverage_reporter/options.rb"                          => {
          actual_ranges:   [],
          display_ranges:  [],
          relevant_ranges: [
            [3, 3],
            [5, 7],
            [9, 9],
            [20, 21],
            [23, 26],
            [28, 29],
            [31, 31],
            [35, 35],
            [37, 39],
            [41, 42],
            [44, 46],
            [51, 51],
            [53, 54],
            [57, 59],
            [61, 61],
            [64, 65],
            [72, 73],
            [77, 78],
            [80, 80]
          ]
        },
        "lib/coverage_reporter/pull_request.rb"                     => {
          actual_ranges:   [[67, 67], [91, 91], [95, 97]],
          display_ranges:  [[67, 67], [91, 91], [95, 97]],
          relevant_ranges: [
            [3, 6],
            [8, 11],
            [14, 15],
            [19, 20],
            [24, 25],
            [29, 30],
            [34, 35],
            [39, 40],
            [44, 45],
            [49, 50],
            [53, 55],
            [58, 59],
            [62, 62],
            [64, 64],
            [66, 67],
            [70, 70],
            [72, 72],
            [78, 82],
            [85, 85],
            [88, 89],
            [91, 91],
            [94, 97]
          ]
        },
        "lib/coverage_reporter/runner.rb"                           => {
          actual_ranges:   [],
          display_ranges:  [],
          relevant_ranges: [[3, 11], [15, 25], [30, 30], [34, 34], [36, 36]]
        },
        "lib/coverage_reporter/uncovered_ranges_extractor.rb"       => {
          actual_ranges:   [],
          display_ranges:  [],
          relevant_ranges: [
            [3, 6],
            [9, 10],
            [12, 12],
            [14, 16],
            [19, 19],
            [22, 22],
            [24, 25],
            [27, 27],
            [30, 31],
            [33, 34],
            [37, 37],
            [39, 39],
            [42, 43],
            [45, 47],
            [49, 50],
            [52, 52],
            [55, 57],
            [62, 63]
          ]
        },
        "spec/coverage_reporter/cli_spec.rb"                        => {
          actual_ranges:   [],
          display_ranges:  [],
          relevant_ranges: [[3, 6], [8, 12], [23, 23], [25, 25], [31, 32], [37, 37], [39, 40], [43, 44], [49, 50]]
        },
        "spec/coverage_reporter/coverage_analyzer_spec.rb"          => {
          actual_ranges:   [],
          display_ranges:  [],
          relevant_ranges: [
            [3, 3],
            [5, 10],
            [12, 16],
            [20, 23],
            [25, 25],
            [27, 31],
            [35, 38],
            [40, 40],
            [42, 46],
            [50, 53],
            [55, 55],
            [57, 61],
            [65, 68],
            [70, 70],
            [72, 76],
            [80, 83],
            [85, 85],
            [87, 91],
            [95, 96],
            [98, 98],
            [103, 103],
            [109, 109],
            [112, 112],
            [117, 119],
            [130, 133],
            [137, 140],
            [142, 142],
            [144, 144],
            [148, 151],
            [155, 158],
            [160, 160],
            [162, 166],
            [170, 173],
            [175, 175],
            [177, 181],
            [185, 188],
            [190, 190],
            [192, 192],
            [196, 199]
          ]
        },
        "spec/coverage_reporter/coverage_report_loader_spec.rb"     => {
          actual_ranges:   [
            [40, 41],
            [43, 43],
            [45, 45],
            [52, 52],
            [56, 56],
            [60, 60]
          ],
          display_ranges:  [[40, 45], [52, 52], [56, 56], [60, 60]],
          relevant_ranges: [
            [3, 5],
            [7, 9],
            [11, 14],
            [16, 19],
            [23, 24],
            [26, 27],
            [34, 36],
            [38, 38],
            [40, 41],
            [43, 43],
            [45, 45],
            [48, 48],
            [52, 52],
            [56, 56],
            [59, 60],
            [67, 69],
            [71, 73],
            [76, 77],
            [80, 81],
            [88, 90],
            [92, 94],
            [97, 98],
            [101, 102],
            [109, 111],
            [114, 115],
            [123, 128],
            [132, 137],
            [141, 142],
            [144, 146],
            [149, 151]
          ]
        },
        "spec/coverage_reporter/coverage_reporter_spec.rb"          => {
          actual_ranges:   [],
          display_ranges:  [],
          relevant_ranges: [[3, 3], [5, 8], [11, 12], [15, 16]]
        },
        "spec/coverage_reporter/global_comment_poster_spec.rb"      => {
          actual_ranges:   [],
          display_ranges:  [],
          relevant_ranges: [
            [3, 3],
            [5, 7],
            [9, 10],
            [16, 20],
            [23, 24],
            [28, 28],
            [32, 33],
            [35, 37],
            [40, 41],
            [46, 46],
            [50, 53],
            [56, 57],
            [61, 61],
            [65, 67],
            [69, 71],
            [74, 75],
            [79, 79],
            [84, 86]
          ]
        },
        "spec/coverage_reporter/global_comment_spec.rb"             => {
          actual_ranges:   [],
          display_ranges:  [],
          relevant_ranges: [
            [3, 3],
            [5, 7],
            [9, 10],
            [17, 20],
            [23, 28],
            [32, 34],
            [37, 39],
            [42, 43],
            [47, 49],
            [51, 52],
            [56, 57],
            [59, 60],
            [65, 66],
            [68, 69]
          ]
        },
        "spec/coverage_reporter/inline_comment_poster_spec.rb"      => {
          actual_ranges:   [],
          display_ranges:  [],
          relevant_ranges: [
            [3, 3],
            [5, 8],
            [10, 10],
            [12, 12],
            [29, 34],
            [37, 38],
            [46, 46],
            [54, 54],
            [58, 60],
            [63, 67],
            [70, 71],
            [76, 76],
            [84, 84],
            [88, 90],
            [92, 93],
            [103, 106],
            [109, 110],
            [115, 115],
            [120, 120],
            [124, 125],
            [127, 129],
            [132, 135],
            [137, 137],
            [141, 144],
            [147, 148],
            [150, 153],
            [155, 155],
            [158, 160],
            [170, 174],
            [177, 178],
            [180, 180],
            [183, 183],
            [185, 186],
            [188, 193],
            [195, 195],
            [199, 200],
            [202, 206],
            [209, 210],
            [212, 212],
            [215, 215],
            [217, 218],
            [221, 221],
            [223, 224],
            [226, 226]
          ]
        },
        "spec/coverage_reporter/inline_comment_spec.rb"             => {
          actual_ranges:   [],
          display_ranges:  [],
          relevant_ranges: [[3, 3], [5, 10], [12, 13], [21, 26], [30, 32], [34, 35], [39, 41], [46, 48], [50, 51], [55, 57]]
        },
        "spec/coverage_reporter/integration_spec.rb"                => {
          actual_ranges:   [[52, 52], [62, 62], [142, 142], [162, 162], [201, 204]],
          display_ranges:  [
            [52, 52],
            [62, 62],
            [142, 142],
            [162, 162],
            [201, 204]
          ],
          relevant_ranges: [
            [3, 3],
            [6, 6],
            [8, 9],
            [19, 21],
            [23, 23],
            [26, 27],
            [30, 32],
            [41, 42],
            [51, 52],
            [61, 62],
            [71, 71],
            [79, 80],
            [83, 84],
            [87, 93],
            [96, 102],
            [107, 108],
            [110, 110],
            [113, 113],
            [117, 117],
            [126, 127],
            [130, 132],
            [141, 142],
            [151, 152],
            [161, 162],
            [171, 171],
            [179, 180],
            [183, 183],
            [186, 187],
            [190, 196],
            [199, 204],
            [209, 210]
          ]
        },
        "spec/coverage_reporter/modified_ranges_extractor_spec.rb"  => {
          actual_ranges:   [],
          display_ranges:  [],
          relevant_ranges: [
            [3, 3],
            [5, 8],
            [10, 11],
            [15, 16],
            [18, 19],
            [23, 24],
            [26, 28],
            [32, 33],
            [35, 36],
            [67, 68],
            [70, 70],
            [75, 75],
            [78, 79],
            [81, 81],
            [85, 86],
            [88, 89],
            [103, 104],
            [106, 106],
            [112, 113],
            [115, 116],
            [130, 131],
            [133, 133],
            [139, 140],
            [142, 143],
            [162, 163],
            [165, 165],
            [171, 172],
            [174, 175],
            [185, 186],
            [188, 188],
            [195, 196],
            [198, 199],
            [202, 203],
            [206, 207],
            [210, 211],
            [214, 215]
          ]
        },
        "spec/coverage_reporter/options_spec.rb"                    => {
          actual_ranges:   [],
          display_ranges:  [],
          relevant_ranges: [
            [3, 3],
            [5, 9],
            [24, 24],
            [26, 26],
            [37, 39],
            [51, 51],
            [55, 59],
            [61, 61],
            [66, 70],
            [72, 72],
            [77, 80],
            [82, 83],
            [87, 90],
            [106, 107],
            [109, 111],
            [114, 116],
            [119, 121],
            [124, 126],
            [129, 131],
            [134, 136],
            [140, 144],
            [147, 150],
            [153, 156],
            [159, 162],
            [167, 169],
            [177, 178],
            [181, 184],
            [186, 186],
            [190, 193],
            [195, 195],
            [199, 202],
            [204, 204],
            [208, 211],
            [213, 213],
            [217, 220],
            [222, 223],
            [227, 229]
          ]
        },
        "spec/coverage_reporter/pull_request_spec.rb"               => {
          actual_ranges:   [[13, 13], [23, 23], [316, 316], [320, 320], [324, 324]],
          display_ranges:  [
            [13, 13],
            [23, 23],
            [316, 316],
            [320, 320],
            [324, 324]
          ],
          relevant_ranges: [
            [3, 4],
            [6, 6],
            [8, 10],
            [12, 13],
            [18, 20],
            [22, 23],
            [27, 31],
            [33, 35],
            [38, 41],
            [44, 47],
            [52, 53],
            [55, 56],
            [59, 60],
            [63, 65],
            [69, 70],
            [72, 73],
            [76, 77],
            [80, 82],
            [86, 88],
            [90, 91],
            [94, 95],
            [98, 100],
            [103, 106],
            [110, 112],
            [114, 115],
            [118, 120],
            [123, 125],
            [129, 132],
            [134, 135],
            [138, 140],
            [143, 145],
            [149, 150],
            [152, 153],
            [156, 158],
            [162, 165],
            [167, 168],
            [171, 173],
            [176, 178],
            [182, 183],
            [185, 186],
            [189, 191],
            [195, 203],
            [223, 226],
            [229, 230],
            [232, 233],
            [241, 241],
            [253, 254],
            [262, 262],
            [269, 271],
            [279, 279],
            [293, 294],
            [296, 297],
            [305, 305],
            [312, 316],
            [319, 320],
            [323, 324],
            [329, 330],
            [333, 335],
            [346, 347],
            [349, 350],
            [353, 355]
          ]
        },
        "spec/coverage_reporter/runner_spec.rb"                     => {
          actual_ranges:   [],
          display_ranges:  [],
          relevant_ranges: [
            [3, 4],
            [6, 7],
            [9, 9],
            [11, 20],
            [22, 31],
            [33, 33],
            [35, 35],
            [44, 45],
            [48, 48],
            [51, 51],
            [54, 54],
            [58, 58],
            [62, 62],
            [66, 66],
            [68, 68],
            [72, 72],
            [80, 80],
            [84, 85],
            [88, 90],
            [92, 95],
            [97, 98],
            [101, 104],
            [106, 107],
            [109, 110]
          ]
        },
        "spec/coverage_reporter/uncovered_ranges_extractor_spec.rb" => {
          actual_ranges:   [],
          display_ranges:  [],
          relevant_ranges: [
            [3, 3],
            [5, 9],
            [13, 16],
            [20, 23],
            [27, 28],
            [30, 30],
            [40, 42],
            [44, 44],
            [55, 55],
            [57, 57],
            [59, 59],
            [61, 61],
            [63, 63],
            [67, 68],
            [70, 70],
            [78, 80],
            [82, 84],
            [88, 89],
            [91, 91],
            [95, 97],
            [101, 102],
            [104, 104],
            [111, 113],
            [115, 116],
            [120, 121],
            [123, 123],
            [128, 129],
            [131, 131],
            [134, 134],
            [136, 136],
            [141, 142],
            [144, 144],
            [147, 147],
            [149, 149],
            [154, 155],
            [157, 157],
            [160, 160],
            [162, 162],
            [167, 168],
            [170, 170],
            [173, 173],
            [175, 175],
            [180, 181],
            [183, 183],
            [186, 186],
            [188, 188],
            [193, 194],
            [196, 196]
          ]
        },
        "spec/coverage_reporter/version_spec.rb"                    => {
          actual_ranges:   [],
          display_ranges:  [],
          relevant_ranges: [[3, 3], [5, 7], [10, 11]]
        }
      }
      expect(result).to eq(expected_result)
    end
  end
end
