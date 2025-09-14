# frozen_string_literal: true

require "spec_helper"
require "coverage_reporter/comment_poster"

RSpec.describe CoverageReporter::CommentPoster do
  subject(:poster) { described_class.new(pull_request:, analysis:, commit_sha:, logger:) }

  let(:pull_request) { instance_double(CoverageReporter::PullRequest) }
  let(:commit_sha) { "abc123" }
  let(:logger) { instance_double(Logger) }
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
    allow(pull_request).to receive_messages(
      inline_comments:      [],
      global_comments:      [],
      add_comment_on_lines: true,
      add_comment:          true,
      update_comment:       true,
      delete_coverage_comments_for_file: true,
      latest_commit_sha:    commit_sha
    )
    allow(logger).to receive(:info)
  end

  describe "#call" do
    context "when commit is the latest commit" do
      it "proceeds with posting comments" do
        expect(pull_request).to receive(:global_comments).and_return([])
        expect(pull_request).to receive(:add_comment_on_lines).at_least(:once)
        expect(pull_request).to receive(:add_comment).at_least(:once)
        
        poster.call
      end

      it "does not log any skip message" do
        expect(logger).not_to receive(:info)
        
        poster.call
      end
    end

    context "when commit is not the latest commit" do
      let(:latest_commit_sha) { "def456" }
      
      before do
        allow(pull_request).to receive(:latest_commit_sha).and_return(latest_commit_sha)
      end

      it "logs a skip message and returns early" do
        expect(logger).to receive(:info).with("Skipping comment posting: commit #{commit_sha} is not the latest commit (#{latest_commit_sha})")
        expect(pull_request).not_to receive(:add_comment_on_lines)
        expect(pull_request).not_to receive(:add_comment)
        
        poster.call
      end
    end
  end

  describe "inline grouping edge cases" do
    let(:uncovered) { { "lib/edge.rb" => [3, 3, 4] } }

    it "groups duplicates into separate chunks according to contiguous rule" do
      poster.call
    end
  end

  describe "comment content" do
    it "includes commit SHA in inline comment body" do
      expect(pull_request).to receive(:add_comment_on_lines) do |args|
        expect(args[:body]).to include("_Commit: #{commit_sha}_")
      end
      
      poster.call
    end

    it "includes commit SHA in global comment body" do
      expect(pull_request).to receive(:add_comment) do |args|
        expect(args[:body]).to include("_Commit: #{commit_sha}_")
      end
      
      poster.call
    end
  end

  describe "cleanup old coverage comments" do
    it "calls delete_coverage_comments_for_file for each file with coverage" do
      expect(pull_request).to receive(:delete_coverage_comments_for_file).with("app/models/user.rb")
      expect(pull_request).to receive(:delete_coverage_comments_for_file).with("lib/foo.rb")
      
      poster.call
    end
  end

  describe "logger parameter" do
    context "when no logger is provided" do
      subject(:poster) { described_class.new(pull_request:, analysis:, commit_sha:) }
      
      it "uses the default logger" do
        expect { poster.call }.not_to raise_error
      end
    end

    context "when a custom logger is provided" do
      let(:custom_logger) { instance_double(Logger) }
      subject(:poster) { described_class.new(pull_request:, analysis:, commit_sha:, logger: custom_logger) }
      
      before do
        allow(custom_logger).to receive(:info)
      end

      it "uses the provided logger" do
        latest_sha = "different_sha"
        allow(pull_request).to receive(:latest_commit_sha).and_return(latest_sha)
        
        expect(custom_logger).to receive(:info).with("Skipping comment posting: commit #{commit_sha} is not the latest commit (#{latest_sha})")
        
        poster.call
      end
    end
  end
end
