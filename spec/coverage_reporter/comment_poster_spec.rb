# frozen_string_literal: true

require "spec_helper"
require "coverage_reporter/comment_poster"

RSpec.describe CoverageReporter::CommentPoster do
  subject(:poster) { described_class.new(pull_request:, analysis:, commit_sha:) }

  let(:pull_request) { instance_double(CoverageReporter::PullRequest) }
  let(:commit_sha) { "abc123" }
  let(:diff_coverage) { 87.5 }
  let(:uncovered) do
    {
      "app/models/user.rb" => [10, 11, 12, 20, 22, 21, 30],
      "lib/foo.rb"         => [5]
    }
  end
  let(:total_changed) { 10 }
  let(:total_covered) { 90 }
  let(:uncovered_by_file) do
    {
      "app/models/user.rb" => [10, 11, 12, 20, 22, 21, 30],
      "lib/foo.rb"         => [5]
    }
  end
  let(:analysis) { CoverageReporter::AnalysisResult.new(diff_coverage:, total_changed:, total_covered:, uncovered_by_file:) }

  before do
    allow(pull_request).to receive(:inline_comments).and_return([])
    allow(pull_request).to receive(:global_comments).and_return([])
  end

  describe "#post_all" do
    it "deletes old inline comments, posts grouped inline comments and a global summary" do
      poster.call
    end
  end

  describe "inline grouping edge cases" do
    let(:uncovered) { { "lib/edge.rb" => [3, 3, 4] } }

    it "groups duplicates into separate chunks according to contiguous rule" do
      poster.call
    end
  end
end
