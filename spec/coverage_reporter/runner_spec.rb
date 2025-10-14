# frozen_string_literal: true

require "spec_helper"
require "coverage_reporter/runner"

RSpec.describe CoverageReporter::Runner do
  subject(:runner) { described_class.new(options) }

  let(:coverage_report_path) { "coverage/coverage.json" }
  # We'll stub all collaborator classes so we only test orchestration
  let(:coverage_report_loader_instance) { instance_double(CoverageReporter::CoverageReportLoader, call: coverage_report_data) }
  let(:uncovered_ranges_extractor_instance) { instance_double(CoverageReporter::UncoveredRangesExtractor, call: coverage) }
  let(:pull_request_instance) { instance_double(CoverageReporter::PullRequest, diff: diff_text) }
  let(:inline_comment_factory_instance) { instance_double(CoverageReporter::InlineCommentFactory) }
  let(:inline_comment_poster_instance) { instance_double(CoverageReporter::InlineCommentPoster) }
  let(:global_comment_factory_instance) { instance_double(CoverageReporter::GlobalCommentFactory) }
  let(:global_comment_poster_instance) { instance_double(CoverageReporter::GlobalCommentPoster) }
  let(:diff_text) { "diff --git a/lib/foo.rb b/lib/foo.rb\n+++ b/lib/foo.rb\n@@ -1,0 +1,3 @@\n+line1\n+line2\n+line3" }
  let(:analysis_result) { { "lib/foo.rb" => [[3, 3]] } }
  let(:modified_uncovered_intersection_instance) { instance_double(CoverageReporter::ModifiedUncoveredIntersection, call: analysis_result) }
  # Provide default values overridden per example
  let(:coverage) { { "lib/foo.rb" => [[1, 2]] } }
  let(:diff) { { "lib/foo.rb" => [[1, 3]] } }
  let(:modified_ranges_extractor_instance) { instance_double(CoverageReporter::ModifiedRangesExtractor, call: diff) }
  let(:coverage_report_data) { { "lib/foo.rb" => { "lines" => [1, 1, 0, 1, nil] } } }
  let(:pr_number) { 99 }
  let(:repo) { "user/repo" }
  let(:github_token)  { "gh-token" }
  let(:commit_sha)    { "abc123" }

  let(:options) do
    {
      coverage_report_path: coverage_report_path,
      github_token:         github_token,
      pr_number:            pr_number,
      repo:                 repo,
      commit_sha:           commit_sha,
      build_url:            nil
    }
  end

  before do
    allow(CoverageReporter::CoverageReportLoader)
      .to receive(:new).with(coverage_report_path).and_return(coverage_report_loader_instance)

    allow(CoverageReporter::UncoveredRangesExtractor)
      .to receive(:new).with(coverage_report_data).and_return(uncovered_ranges_extractor_instance)

    allow(CoverageReporter::ModifiedRangesExtractor)
      .to receive(:new).with(diff_text).and_return(modified_ranges_extractor_instance)

    allow(CoverageReporter::ModifiedUncoveredIntersection)
      .to receive(:new).with(uncovered_ranges: coverage, modified_ranges: diff)
      .and_return(modified_uncovered_intersection_instance)

    allow(CoverageReporter::PullRequest)
      .to receive(:new).with(github_token: github_token, repo: repo, pr_number: pr_number)
      .and_return(pull_request_instance)

    allow(CoverageReporter::InlineCommentFactory)
      .to receive(:new).with(intersection: analysis_result, commit_sha: commit_sha)
      .and_return(inline_comment_factory_instance)

    allow(inline_comment_factory_instance).to receive(:call).and_return([])

    allow(CoverageReporter::InlineCommentPoster)
      .to receive(:new).with(pull_request: pull_request_instance, commit_sha: commit_sha, inline_comments: [])
      .and_return(inline_comment_poster_instance)

    allow(CoverageReporter::GlobalCommentFactory)
      .to receive(:new).with(commit_sha: commit_sha)
      .and_return(global_comment_factory_instance)

    allow(global_comment_factory_instance).to receive(:call).and_return(instance_double(CoverageReporter::GlobalComment))

    allow(CoverageReporter::GlobalCommentPoster)
      .to receive(:new).with(pull_request: pull_request_instance, global_comment: anything)
      .and_return(global_comment_poster_instance)

    allow(inline_comment_poster_instance).to receive(:call)
    allow(global_comment_poster_instance).to receive(:call)
  end

  describe "#run" do
    it "parses coverage, fetches diff, analyzes, and publishes inline & global comments" do
      runner.run

      expect(coverage_report_loader_instance).to have_received(:call).once
      expect(uncovered_ranges_extractor_instance).to have_received(:call).once
      expect(modified_ranges_extractor_instance).to have_received(:call).once
      expect(modified_uncovered_intersection_instance).to have_received(:call).once

      expect(inline_comment_poster_instance).to have_received(:call)
      expect(global_comment_poster_instance).to have_received(:call)
    end

    context "when there are no uncovered lines" do
      let(:analysis_result) { {} }
      let(:coverage) { { "lib/bar.rb" => [[5, 6, 7]] } }
      let(:diff) { { "lib/bar.rb" => [[5, 6, 7]] } }

      it "still publishes both inline (with empty mapping) and global comments" do
        runner.run

        expect(inline_comment_poster_instance).to have_received(:call)
        expect(global_comment_poster_instance).to have_received(:call)
      end
    end
  end
end
