# frozen_string_literal: true

require "spec_helper"
require "coverage_reporter/coverage_collator"

RSpec.describe CoverageReporter::CoverageCollator do
  describe "#call" do
    let(:coverage_dir) { "test_coverage" }
    let(:filenames) { nil }
    let(:collator) { described_class.new(coverage_dir: coverage_dir, filenames: filenames) }
    let(:coverage_files) { ["#{coverage_dir}/resultset-1.json", "#{coverage_dir}/resultset-2.json"] }

    before do
      allow(collator).to receive(:require)
      allow(Dir).to receive(:[]).with("#{coverage_dir}/resultset-*.json").and_return(coverage_files)
    end

    it "collates coverage files and generates reports" do
      expect(Dir).to receive(:[]).with("#{coverage_dir}/resultset-*.json").and_return(coverage_files)
      expect(SimpleCov).to receive(:collate).with(coverage_files)

      expect { collator.call }.to output(/Collate coverage files: .*resultset-1\.json.*resultset-2\.json.*\n.*✅ Coverage merged and report generated\./).to_stdout
    end

    context "when no coverage files exist" do
      let(:coverage_files) { [] }

      it "aborts with error" do
        expect { collator.call }.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end
      end
    end

    context "when filenames are provided" do
      let(:filenames) { ["sample.rb"] }

      it "passes a block to SimpleCov.collate" do
        block_received = false
        allow(SimpleCov).to receive(:collate) do |_files, &block|
          block_received = !block.nil?
        end

        collator.call
        expect(block_received).to be true
      end
    end
  end
end
