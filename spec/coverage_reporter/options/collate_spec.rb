# frozen_string_literal: true

require "spec_helper"
require "coverage_reporter/options/collate"

RSpec.describe CoverageReporter::Options::Collate do
  describe ".parse" do
    context "when using default options" do
      it "returns default coverage_dir" do
        result = described_class.parse([])
        expect(result).to eq(coverage_dir: "coverage")
      end
    end

    context "when overriding coverage_dir via CLI args" do
      it "applies the override" do
        result = described_class.parse(["--coverage-dir", "custom/coverage"])
        expect(result).to eq(coverage_dir: "custom/coverage")
      end
    end

    context "when help flag -h is provided" do
      it "prints usage and exits 0" do
        expect do
          described_class.parse(["-h"])
        end.to raise_error(SystemExit) { |e|
          expect(e.status).to eq(0)
        }
      end
    end

    context "when help flag --help is provided" do
      it "prints usage and exits 0" do
        expect do
          described_class.parse(["--help"])
        end.to raise_error(SystemExit) { |e|
          expect(e.status).to eq(0)
        }
      end
    end

    context "immutability / independence of returned hash" do
      it "returns a new hash (mutating result does not change defaults)" do
        result = described_class.parse(["--coverage-dir", "custom"])
        result[:coverage_dir] = "changed"

        again = described_class.parse(["--coverage-dir", "custom"])
        expect(again[:coverage_dir]).to eq("custom")
      end
    end
  end

  describe ".defaults" do
    it "returns the default options" do
      expect(described_class.defaults).to eq(coverage_dir: "coverage")
    end
  end
end
