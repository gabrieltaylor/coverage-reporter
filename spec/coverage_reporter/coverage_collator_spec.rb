# frozen_string_literal: true

require "spec_helper"
require "coverage_reporter/coverage_collator"

RSpec.describe CoverageReporter::CoverageCollator do
  describe "#call" do
    let(:coverage_dir) { "test_coverage" }
    let(:collator) { described_class.new(coverage_dir: coverage_dir) }

    before do
      # Mock the required dependencies
      allow(collator).to receive(:require).with("simplecov")
      allow(collator).to receive(:require).with("simplecov_json_formatter")
      allow(collator).to receive(:require).with("simplecov_hypertext")
      allow(collator).to receive(:require).with("coverage_reporter/simple_cov/patches/result_hash_formatter_patch")

      # Mock Dir.glob to return test files
      allow(Dir).to receive(:[]).with("#{coverage_dir}/resultset-*.json").and_return(
        [
          "#{coverage_dir}/resultset-1.json",
          "#{coverage_dir}/resultset-2.json"
        ]
      )

      # Mock SimpleCov.collate
      allow(SimpleCov).to receive(:collate)
    end

    context "when coverage files exist" do
      it "collates the files and generates reports" do
        expect(Dir).to receive(:[]).with("#{coverage_dir}/resultset-*.json")
        expect(SimpleCov).to receive(:collate).with(
          [
            "#{coverage_dir}/resultset-1.json",
            "#{coverage_dir}/resultset-2.json"
          ]
        )

        expect { collator.call }.to output(/Collate coverage files: .*resultset-1\.json.*resultset-2\.json/).to_stdout
        expect { collator.call }.to output(/✅ Coverage merged and report generated\./).to_stdout
      end
    end

    context "when no coverage files exist" do
      before do
        allow(Dir).to receive(:[]).with("#{coverage_dir}/resultset-*.json").and_return([])
      end

      it "aborts with error message" do
        expect { collator.call }.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end
      end
    end
  end
end
