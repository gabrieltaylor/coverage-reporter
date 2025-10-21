# frozen_string_literal: true

require "spec_helper"
require "coverage_reporter/cli"
require "coverage_reporter/options/report"
require "coverage_reporter/runner"

RSpec.describe CoverageReporter::CLI do
  describe ".start" do
    context "when no command is provided" do
      it "shows usage and exits with error" do
        expect do
          described_class.start([])
        end.to raise_error(SystemExit) { |e|
          expect(e.status).to eq(1)
        }
      end
    end

    context "when report command is provided" do
      let(:argv) do
        %w[report --coverage-report-path custom/result.json --github-token secret --repo owner/repo --pr-number 123 --commit-sha abc123]
      end
      let(:parsed_options) do
        {
          coverage_report_path: "custom/result.json",
          github_token:         "secret",
          repo:                 "owner/repo",
          pr_number:            "123",
          commit_sha:           "abc123",
          report_url:           nil
        }
      end

      it "parses options, instantiates a Runner with them, and calls run" do
        # Stub the parser
        expect(CoverageReporter::Options::Report)
          .to receive(:parse)
          .with(argv[1..])
          .and_return(parsed_options)

        # Runner double
        runner = instance_double(CoverageReporter::Runner)
        expect(CoverageReporter::Runner)
          .to receive(:new)
          .with(parsed_options)
          .and_return(runner)

        expect(runner).to receive(:run).and_return(:ok)

        result = described_class.start(argv)
        expect(result).to eq(:ok)
      end

      it "propagates SystemExit raised during option parsing (e.g., missing required args)" do
        expect(CoverageReporter::Options::Report)
          .to receive(:parse)
          .with(argv[1..])
          .and_raise(SystemExit.new(1))

        expect do
          described_class.start(argv)
        end.to raise_error(SystemExit)
      end
    end

    context "when collate command is provided" do
      let(:argv) { %w[collate --coverage-dir custom/coverage] }
      let(:parsed_options) do
        {
          coverage_dir: "custom/coverage"
        }
      end

      it "parses collate options and calls CoverageCollator" do
        expect(CoverageReporter::Options::Collate)
          .to receive(:parse)
          .with(argv[1..])
          .and_return(parsed_options)

        collator = instance_double(CoverageReporter::CoverageCollator)
        expect(CoverageReporter::CoverageCollator)
          .to receive(:new)
          .with(parsed_options)
          .and_return(collator)

        expect(collator).to receive(:call).and_return(:ok)

        result = described_class.start(argv)
        expect(result).to eq(:ok)
      end
    end

    context "when unknown command is provided" do
      it "shows error message and exits with error" do
        expect do
          described_class.start(["unknown"])
        end.to raise_error(SystemExit) { |e|
          expect(e.status).to eq(1)
        }
      end
    end
  end
end
