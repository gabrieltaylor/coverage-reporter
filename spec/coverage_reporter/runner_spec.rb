# frozen_string_literal: true

require "spec_helper"
require "coverage_reporter/runner"

RSpec.describe CoverageReporter::Runner do
  subject(:runner) { described_class.new(options) }

  let(:coverage_path) { "coverage/.resultset.json" }
  # We'll stub all collaborator classes so we only test orchestration
  let(:parser_instance) { instance_double(CoverageReporter::CoverageParser, call: coverage) }
  let(:diff_instance)   { instance_double(CoverageReporter::DiffParser, call: diff) }
  let(:pull_request_instance) { instance_double(CoverageReporter::PullRequest) }
  let(:poster_instance) { instance_double(CoverageReporter::CommentPoster) }
  let(:analysis_result) do
    CoverageReporter::AnalysisResult.new(
      uncovered_by_file: uncovered_by_file,
      diff_coverage:     diff_coverage,
      total_changed:     total_changed,
      total_covered:     total_covered
    )
  end
  let(:analyser_instance) { instance_double(CoverageReporter::CoverageAnalyser, call: analysis_result) }
  # Provide default values overridden per example
  let(:coverage) { { "lib/foo.rb" => [1, 2] } }
  let(:diff) { { "lib/foo.rb" => [1, 2, 3] } }
  let(:uncovered_by_file) { { "lib/foo.rb" => [3] } }
  let(:diff_coverage) { 66.67 }
  let(:total_changed) { 3 }
  let(:total_covered) { 2 }
  let(:pr_number) { 99 }
  let(:repo) { "user/repo" }
  let(:html_root)     { "coverage" }
  let(:access_token)  { "gh-token" }
  let(:base_ref)      { "origin/main" }
  let(:commit_sha)    { "abc123" }

  let(:options) do
    {
      coverage_path: coverage_path,
      html_root:     html_root,
      access_token:  access_token,
      base_ref:      base_ref,
      pr_number:     pr_number,
      repo:          repo,
      commit_sha:    commit_sha
    }
  end

  before do
    allow(CoverageReporter::CoverageParser)
      .to receive(:new).with(coverage_path).and_return(parser_instance)

    allow(CoverageReporter::DiffParser)
      .to receive(:new).with(base_ref).and_return(diff_instance)

    allow(CoverageReporter::CoverageAnalyser)
      .to receive(:new).with(coverage: coverage, diff: diff)
      .and_return(analyser_instance)

    allow(CoverageReporter::PullRequest)
      .to receive(:new).with(access_token: access_token, repo: repo, pr_number: pr_number)
      .and_return(pull_request_instance)

    allow(CoverageReporter::CommentPoster)
      .to receive(:new).with(pull_request: pull_request_instance, analysis: analysis_result, commit_sha: commit_sha)
      .and_return(poster_instance)

    allow(poster_instance).to receive(:call)
  end

  describe "#run" do
    it "parses coverage, fetches diff, analyzes, and publishes inline & global comments" do
      runner.run

      expect(parser_instance).to have_received(:call).once
      expect(diff_instance).to have_received(:call).once
      expect(analyser_instance).to have_received(:call).once

      expect(poster_instance).to have_received(:call)
    end

    context "when there are no uncovered lines" do
      let(:uncovered_by_file) { {} }
      let(:coverage) { { "lib/bar.rb" => [5, 6, 7] } }
      let(:diff) { { "lib/bar.rb" => [5, 6, 7] } }
      let(:diff_coverage) { 100.0 }

      it "still publishes both inline (with empty mapping) and global comments" do
        runner.run

        expect(poster_instance).to have_received(:call)
      end
    end
  end
end
