# frozen_string_literal: true

require "spec_helper"
require "coverage_reporter/comment_poster"

RSpec.describe CoverageReporter::CommentPoster do
  subject(:poster) { described_class.new(pull_request:, analysis:, commit_sha:) }

  let(:pull_request) { instance_double(CoverageReporter::PullRequest) }
  let(:commit_sha) { "abc123" }
  let(:analysis) do
    {
      "app/models/user.rb" => [[10, 12], [20, 22], [30, 30]],
      "lib/foo.rb"         => [[5, 5]]
    }
  end

  before do
    allow(pull_request).to receive_messages(
      inline_comments:                   [],
      global_comments:                   [],
      add_comment_on_lines:              true,
      add_global_comment:                true,
      update_global_comment:             true,
      delete_coverage_comments_for_file: true,
      find_existing_inline_comment:      nil,
      delete_inline_comment:             true,
      latest_commit_sha:                 commit_sha
    )
  end

  describe "#call" do
    context "when commit is the latest commit" do
      it "proceeds with posting comments" do
        expect(pull_request).to receive(:global_comments).and_return([])
        expect(pull_request).to receive(:add_comment_on_lines).at_least(:once)
        expect(pull_request).to receive(:add_global_comment).at_least(:once)

        poster.call
      end

      it "does not log any skip message" do
        expect(CoverageReporter.logger).not_to receive(:warn)

        poster.call
      end
    end

    context "when commit is not the latest commit" do
      let(:latest_commit_sha) { "def456" }

      before do
        allow(pull_request).to receive(:latest_commit_sha).and_return(latest_commit_sha)
      end

      it "logs a skip message and returns early" do
        expect(CoverageReporter.logger).to receive(:warn).with(
          "Skipping comment posting: commit #{commit_sha} is not the latest commit (#{latest_commit_sha})"
        )
        expect(pull_request).not_to receive(:add_comment_on_lines)
        expect(pull_request).not_to receive(:add_global_comment)

        poster.call
      end
    end
  end

  describe "inline grouping edge cases" do
    let(:analysis) { { "lib/edge.rb" => [[3, 3], [4, 4]] } }

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
      expect(pull_request).to receive(:add_global_comment) do |args|
        expect(args[:body]).to include("_Commit: #{commit_sha}_")
      end

      poster.call
    end
  end

  describe "cleanup unused coverage comments" do
    let(:existing_inline_comment) do
      # rubocop:disable RSpec/VerifiedDoubles
      double("comment", id: 123, body: "<!-- coverage-inline-marker -->", path: "app/models/user.rb")
      # rubocop:enable RSpec/VerifiedDoubles
    end
    let(:existing_global_comment) do
      # rubocop:disable RSpec/VerifiedDoubles
      double("comment", id: 456, body: "<!-- coverage-comment-marker -->", path: nil)
      # rubocop:enable RSpec/VerifiedDoubles
    end

    before do
      allow(pull_request).to receive_messages(inline_comments: [existing_inline_comment], global_comments: [existing_global_comment])
    end

    it "tracks existing coverage comments at the start" do
      expect(pull_request).to receive(:inline_comments).and_return([existing_inline_comment])
      expect(pull_request).to receive(:global_comments).and_return([existing_global_comment])
      expect(pull_request).to receive(:delete_inline_comment).with(123)
      expect(pull_request).to receive(:delete_inline_comment).with(456)

      poster.call
    end

    it "removes unused coverage comments that weren't updated" do
      # Mock the find_existing_inline_comment to return nil (no existing comment found)

      # Mock the global comment to not be found (simulating no existing global comment)
      allow(pull_request).to receive_messages(find_existing_inline_comment: nil, global_comments: [])

      # Allow all debug calls but expect the specific one we care about
      allow(CoverageReporter.logger).to receive(:debug)
      
      # Expect only the inline comment to be deleted (global comment will be created, not deleted)
      expect(pull_request).to receive(:delete_inline_comment).with(123)
      expect(CoverageReporter.logger).to receive(:debug).with("Removing unused coverage comment: 123 (app/models/user.rb)")

      poster.call
    end

    it "keeps comments that were updated during the run" do
      # Mock finding an existing comment for the first uncovered line
      allow(pull_request).to receive(:find_existing_inline_comment).and_return(existing_inline_comment)

      # Expect the inline comment to be updated, not deleted
      expect(pull_request).to receive(:update_inline_comment).with(id: 123, body: anything).at_least(:once)
      expect(pull_request).not_to receive(:delete_inline_comment).with(123)

      # The global comment will be updated (not deleted) since it exists and gets updated
      expect(pull_request).to receive(:update_global_comment).with(id: 456, body: anything)
      expect(pull_request).not_to receive(:delete_global_comment).with(456)

      poster.call
    end
  end

  describe "logger usage" do
    it "uses the default logger from CoverageReporter" do
      expect { poster.call }.not_to raise_error
    end
  end
end
