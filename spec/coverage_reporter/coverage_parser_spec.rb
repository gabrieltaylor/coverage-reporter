# frozen_string_literal: true

require "spec_helper"
require "coverage_reporter/coverage_parser"
require "tempfile"

RSpec.describe CoverageReporter::CoverageParser do
  def write_resultset(json_obj)
    file = Tempfile.new("coverage_resultset")
    file.write(JSON.dump(json_obj))
    file.flush
    file
  end

  context "when the resultset file does not exist" do
    it "returns an empty hash" do
      parser = described_class.new("nonexistent/file/path.json")
      expect(parser.call).to eq({})
    end
  end

  context "when the JSON is invalid" do
    it "returns an empty hash" do
      file = Tempfile.new("coverage_resultset")
      file.write("{ invalid json")
      file.flush

      parser = described_class.new(file.path)
      expect(parser.call).to eq({})
    end
  end

  context "when the top-level JSON is not a Hash" do
    it "returns an empty hash" do
      file = write_resultset(["array", "not", "hash"])
      parser = described_class.new(file.path)
      expect(parser.call).to eq({})
    end
  end

  context "with mixed legacy and newer schema entries" do
    let(:json) do
      {
        # Legacy style entry, using "coverage" hash directly
        "RSpec" => {
          "coverage" => {
            # Array style (indexes -> line numbers)
            "lib/foo.rb"  => [nil, 1, 0, 2], # lines 2 & 4 covered
            # Hash style (explicit string keys mapping to counts)
            "lib/bar.rb"  => { "1" => 1, "2" => 0, "5" => 3 }, # lines 1 & 5 covered
            # Hash with "lines" array (SimpleCov sometimes nests)
            "lib/qux.rb"  => { "lines" => [nil, 0, 5] },       # line 3 covered
            # Pure hash style (no "lines" key)
            "lib/quux.rb" => { "1" => 0, "2" => 2, "4" => "3" } # lines 2 & 4 covered
          }
        },
        # Newer style entry, using "files" array
        "Other" => {
          "files" => [
            { "filename" => "lib/baz.rb", "coverage" => [nil, 0, 1, 1] },   # lines 3 & 4 covered
            { "filename" => "lib/skip.rb", "coverage" => "not-an-array" }, # ignored
            { "filename" => "lib/foo.rb", "coverage" => [nil, 0, 1] }      # adds line 3 to lib/foo.rb
          ]
        },
        # An entry that is not a hash (should be skipped gracefully)
        "Garbage" => "not a hash"
      }
    end

    it "parses and aggregates covered lines across schemas without duplicates" do
      file = write_resultset(json)
      parser = described_class.new(file.path)

      result = parser.call

      expect(result.keys).to match_array(
        %w[
          lib/foo.rb
          lib/bar.rb
          lib/qux.rb
          lib/quux.rb
          lib/baz.rb
        ]
      )

      # lib/foo.rb: first entry => lines 2 & 4; second entry adds line 3
      expect(result["lib/foo.rb"]).to match_array([2, 3, 4])
      expect(result["lib/bar.rb"]).to match_array([1, 5])
      expect(result["lib/qux.rb"]).to match_array([3])
      expect(result["lib/quux.rb"]).to match_array([2, 4])
      expect(result["lib/baz.rb"]).to match_array([3, 4])
    end
  end

  context "when multiple entries provide overlapping coverage for the same file" do
    let(:json) do
      {
        "A" => {
          "coverage" => {
            "lib/dup.rb" => [nil, 1, 0, 2] # lines 2 & 4
          }
        },
        "B" => {
          "files" => [
            { "filename" => "lib/dup.rb", "coverage" => [nil, 0, 1] } # line 3
          ]
        },
        "C" => {
          "coverage" => {
            "lib/dup.rb" => { "6" => 1, "2" => 5 } # lines 6 & 2 (2 already present)
          }
        }
      }
    end

    it "unions line numbers without duplicates" do
      file = write_resultset(json)
      parser = described_class.new(file.path)
      result = parser.call

      expect(result["lib/dup.rb"]).to match_array([2, 3, 4, 6])
    end
  end

  context "when an entry has an empty or invalid coverage section" do
    let(:json) do
      {
        "EmptyCoverage" => { "coverage" => {} },
        "NilCoverage"   => { "coverage" => nil },
        "BadFiles"      => { "files" => [{ "filename" => "x.rb" }] }, # missing array
        "NonArrayFiles" => { "files" => "not-an-array" }
      }
    end

    it "returns an empty hash" do
      file = write_resultset(json)
      parser = described_class.new(file.path)
      expect(parser.call).to eq({})
    end
  end

  context "with zero / nil / non-positive counts in arrays and hashes" do
    let(:json) do
      {
        "Example" => {
          "coverage" => {
            "lib/array_style.rb" => [0, nil, 1, "2", -1], # lines 3 & 4 covered (1, "2".to_i => 2)
            "lib/hash_style.rb"  => { "1" => 0, "2" => "0", "3" => nil, "4" => -5, "5" => 1 } # line 5
          }
        }
      }
    end

    it "only includes lines with positive counts" do
      file = write_resultset(json)
      parser = described_class.new(file.path)
      result = parser.call

      expect(result["lib/array_style.rb"]).to match_array([3, 4])
      expect(result["lib/hash_style.rb"]).to match_array([5])
    end
  end

  context "when a coverage file entry mixes types incorrectly" do
    let(:json) do
      {
        "Mixed" => {
          "coverage" => {
            # Unsupported type (String) should be ignored safely
            "lib/weird.rb" => "not valid"
          }
        }
      }
    end
  end
end
