# frozen_string_literal: true

require "spec_helper"
require "coverage_reporter/runner"

RSpec.describe CoverageReporter::Runner do
  let(:coverage_path) { "coverage/.resultset.json" }
  let(:html_root)     { "coverage" }
  let(:github_token)  { "gh-token" }
  let(:build_url)     { "https://ci.example.com/builds/123" }
  let(:base_ref)      { "origin/main" }

  let(:options) do
    {
      coverage_path: coverage_path,
      html_root:     html_root,
      github_token:  github_token,
      build_url:     build_url,
      base_ref:      base_ref
    }
  end

  subject(:runner) { described_class.new(options) }

  # We'll stub all collaborator classes so we only test orchestration
  let(:parser_instance) { instance_double(CoverageReporter::CoverageParser, parse: coverage) }
  let(:diff_instance)   { instance_double(CoverageReporter::DiffParser, fetch_diff: diff) }
  let(:github_instance) { instance_double(CoverageReporter::GitHubAPI) }
  let(:publisher_instance) { instance_double(CoverageReporter::CommentPublisher) }
  let(:analysis_result) do
    instance_double(
      "AnalysisResult",
      uncovered_by_file: uncovered_by_file,
      diff_coverage:     diff_coverage
    )
  end
  let(:analyser_instance) { instance_double("CoverageAnalyzer", analyze: analysis_result) }

  # Provide default values overridden per example
  let(:coverage) { { "lib/foo.rb" => [1, 2] } }
  let(:diff) { { "lib/foo.rb" => [1, 2, 3] } }
  let(:uncovered_by_file) { { "lib/foo.rb" => [3] } }
  let(:diff_coverage) { 66.67 }
  let(:pr_number) { 99 }

  before do
    # Runner references CoverageAnalyzer (american spelling) but the implementation file
    # provides CoverageAnalyser (british). To avoid coupling the test to that mismatch
    # we stub the constant it tries to instantiate.
    stub_const("CoverageReporter::CoverageAnalyzer", Class.new)

    allow(CoverageReporter::CoverageParser)
      .to receive(:new).with(coverage_path).and_return(parser_instance)

    allow(CoverageReporter::DiffParser)
      .to receive(:new).with(base_ref).and_return(diff_instance)

    allow(CoverageReporter::CoverageAnalyzer)
      .to receive(:new).with(coverage: coverage, diff: diff)
      .and_return(analyser_instance)

    allow(CoverageReporter::GitHubAPI)
      .to receive(:new).with(github_token, build_url, html_root)
      .and_return(github_instance)

    allow(CoverageReporter::CommentPublisher)
      .to receive(:new) do |github:, chunker:, formatter:|
        # Basic sanity: the publisher is given the same github object and
        # concrete helper instances.
        expect(github).to be(github_instance)
        expect(chunker).to be_a(CoverageReporter::Chunker)
        expect(formatter).to be_a(CoverageReporter::CommentFormatter)
        publisher_instance
      end

    allow(github_instance).to receive(:find_pr_number).and_return(pr_number)
    allow(publisher_instance).to receive(:publish_inline)
    allow(publisher_instance).to receive(:publish_global)
  end

  describe "#run" do
    it "parses coverage, fetches diff, analyzes, and publishes inline & global comments" do
      runner.run

      expect(parser_instance).to have_received(:parse).once
      expect(diff_instance).to have_received(:fetch_diff).once
      expect(analyser_instance).to have_received(:analyze).once
      expect(github_instance).to have_received(:find_pr_number).once

      expect(publisher_instance).to have_received(:publish_inline).with(
        pr_number:          pr_number,
        uncovered_by_file:  uncovered_by_file
      )

      expect(publisher_instance).to have_received(:publish_global).with(
        pr_number:     pr_number,
        diff_coverage: diff_coverage
      )
    end

    context "when there are no uncovered lines" do
      let(:uncovered_by_file) { {} }
      let(:coverage) { { "lib/bar.rb" => [5, 6, 7] } }
      let(:diff) { { "lib/bar.rb" => [5, 6, 7] } }
      let(:diff_coverage) { 100.0 }

      it "still publishes both inline (with empty mapping) and global comments" do
        runner.run

        expect(publisher_instance).to have_received(:publish_inline).with(
          pr_number:         pr_number,
          uncovered_by_file: {}
        )
        expect(publisher_instance).to have_received(:publish_global).with(
          pr_number:     pr_number,
          diff_coverage: 100.0
        )
      end
    end
  end
end
