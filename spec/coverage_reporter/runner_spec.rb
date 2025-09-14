# frozen_string_literal: true

require "spec_helper"
require "coverage_reporter/runner"

RSpec.describe CoverageReporter::Runner do
  subject(:runner) { described_class.new(options) }

  let(:coverage_path) { "coverage/.resultset.json" }
  # We'll stub all collaborator classes so we only test orchestration
  let(:parser_instance) { instance_double(CoverageReporter::CoverageParser, call: coverage) }
  let(:diff_instance)   { instance_double(CoverageReporter::DiffParser, call: diff) }
  let(:pull_request_instance) { instance_double(CoverageReporter::PullRequest, pull_request_diff: diff_text) }
  let(:poster_instance) { instance_double(CoverageReporter::CommentPoster) }
  let(:diff_text) { "diff --git a/lib/foo.rb b/lib/foo.rb\n+++ b/lib/foo.rb\n@@ -1,0 +1,3 @@\n+line1\n+line2\n+line3" }
  let(:analysis_result) { { "lib/foo.rb" => [[3, 3]] } }
  let(:analyser_instance) { instance_double(CoverageReporter::CoverageAnalyser, call: analysis_result) }
  # Provide default values overridden per example
  let(:coverage) { { "lib/foo.rb" => [1, 2] } }
  let(:diff) { { "lib/foo.rb" => [1, 2, 3] } }
  let(:pr_number) { 99 }
  let(:repo) { "user/repo" }
  let(:html_root)     { "coverage" }
  let(:github_token)  { "gh-token" }
  let(:base_ref)      { "origin/main" }
  let(:commit_sha)    { "abc123" }

  let(:options) do
    {
      coverage_path: coverage_path,
      html_root:     html_root,
      github_token:  github_token,
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
      .to receive(:new).with(diff_text).and_return(diff_instance)

    allow(CoverageReporter::CoverageAnalyser)
      .to receive(:new).with(coverage: coverage, diff: diff)
      .and_return(analyser_instance)

    allow(CoverageReporter::PullRequest)
      .to receive(:new).with(github_token: github_token, repo: repo, pr_number: pr_number)
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
      let(:analysis_result) { {} }
      let(:coverage) { { "lib/bar.rb" => [5, 6, 7] } }
      let(:diff) { { "lib/bar.rb" => [5, 6, 7] } }

      it "still publishes both inline (with empty mapping) and global comments" do
        runner.run

        expect(poster_instance).to have_received(:call)
      end
    end
  end
end
