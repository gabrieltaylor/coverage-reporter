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

    context "when filter is provided" do
      let(:collator) { described_class.new(coverage_dir: coverage_dir, filter: filter) }
      let(:add_filter_calls) { [] }

      before do
        # Capture add_filter_calls in a closure variable
        calls = add_filter_calls

        allow(SimpleCov).to receive(:collate) do |_files, &block|
          # Capture filter and formats values before executing block
          filter_value = collator.send(:filter)
          formats_value = collator.send(:formats)

          # Create a context where add_filter, formatter, filter, and formats are available
          config_obj = Object.new
          config_obj.define_singleton_method(:add_filter) do |filter_arg|
            calls << filter_arg
          end
          config_obj.define_singleton_method(:formatter) { |_| }
          config_obj.define_singleton_method(:filter) { filter_value }
          config_obj.define_singleton_method(:formats) { formats_value }

          config_obj.instance_eval(&block)
        end
      end

      context "when filter is an empty array" do
        let(:filter) { [] }

        it "calls add_filter with empty array" do
          collator.call
          expect(add_filter_calls).to include([])
        end
      end

      context "when filter is a list of filenames" do
        let(:filter) { ["lib/sample.rb", "app/models/user.rb", "spec/helper.rb"] }

        it "calls add_filter with the list of filenames" do
          collator.call
          expect(add_filter_calls).to include(filter)
        end

        it "passes the exact array provided" do
          collator.call
          expect(add_filter_calls).to include(
            ["lib/sample.rb", "app/models/user.rb", "spec/helper.rb"]
          )
        end
      end

      context "when filter is a single filename" do
        let(:filter) { ["lib/sample.rb"] }

        it "calls add_filter with the single filename array" do
          collator.call
          expect(add_filter_calls).to include(["lib/sample.rb"])
        end
      end

      context "when filter contains files with various path formats" do
        let(:filter) do
          [
            "lib/coverage_reporter.rb",
            "app/models/user.rb",
            "spec/coverage_reporter/cli_spec.rb",
            "config/database.yml"
          ]
        end

        it "calls add_filter with all filenames" do
          collator.call
          expect(add_filter_calls).to include(filter)
        end
      end
    end
  end
end
