# frozen_string_literal: true

require "spec_helper"
require "coverage_reporter/cli"
require "coverage_reporter/options"
require "coverage_reporter/runner"

RSpec.describe CoverageReporter::CLI do
  describe ".start" do
    let(:argv) { %w[--coverage-path custom/result.json --html-root custom_html --github-token secret] }
    let(:parsed_options) do
      {
        coverage_path: "custom/result.json",
        html_root:     "custom_html",
        github_token:  "secret",
        report_url:    nil,
        commit_sha:    nil,
        pr_number:     nil,
        repo:          nil
      }
    end

    it "parses options, instantiates a Runner with them, and calls run" do
      # Stub the parser
      expect(CoverageReporter::Options)
        .to receive(:parse)
        .with(argv)
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
      expect(CoverageReporter::Options)
        .to receive(:parse)
        .with(argv)
        .and_raise(SystemExit.new(1))

      expect do
        described_class.start(argv)
      end.to raise_error(SystemExit)
    end
  end
end
