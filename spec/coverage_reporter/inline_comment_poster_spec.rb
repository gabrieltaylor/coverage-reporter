# frozen_string_literal: true

require "spec_helper"

RSpec.describe CoverageReporter::InlineCommentPoster do
  let(:pull_request) { instance_double(CoverageReporter::PullRequest) }
  let(:commit_sha) { "abc123" }
  let(:poster) { described_class.new(pull_request: pull_request, commit_sha: commit_sha, inline_comments: inline_comments) }

  let(:inline_comments) do
    [
      CoverageReporter::InlineComment.new(
        path:       "app/models/user.rb",
        start_line: 5,
        line:       5,
        body:       "<!-- coverage-inline-marker -->\n❌ Line 5 is not covered by tests.\n\n" \
                    "_File: app/models/user.rb, line 5_\n_Commit: abc123_"
      ),
      CoverageReporter::InlineComment.new(
        path:       "app/controllers/users_controller.rb",
        start_line: 10,
        line:       15,
        body:       "<!-- coverage-inline-marker -->\n❌ Lines 10–15 are not covered by tests.\n\n" \
                    "_File: app/controllers/users_controller.rb, line 10_\n_Commit: abc123_"
      )
    ]
  end

  describe "#call" do
    context "when comments don't exist yet" do
      before do
        allow(pull_request).to receive(:inline_comments).and_return([])
        allow(pull_request).to receive(:add_comment_on_lines)
        allow(pull_request).to receive(:delete_inline_comment)
      end

      it "posts all inline comments" do
        expect(pull_request).to receive(:add_comment_on_lines).with(
          commit_id:  commit_sha,
          path:       "app/models/user.rb",
          start_line: 5,
          line:       5,
          body:       inline_comments[0].body
        )

        expect(pull_request).to receive(:add_comment_on_lines).with(
          commit_id:  commit_sha,
          path:       "app/controllers/users_controller.rb",
          start_line: 10,
          line:       15,
          body:       inline_comments[1].body
        )

        poster.call
      end
    end

    context "when some comments already exist" do
      let(:existing_comment) do
        instance_double(Comment, id: 123, body: "<!-- coverage-inline-marker -->\nfoo", start_line: 5, line: 5, path: "app/models/user.rb")
      end

      before do
        allow(pull_request).to receive(:inline_comments).and_return([existing_comment])
        allow(pull_request).to receive(:update_inline_comment)
        allow(pull_request).to receive(:add_comment_on_lines)
        allow(pull_request).to receive(:delete_inline_comment)
      end

      it "updates existing comments and creates new ones" do
        expect(pull_request).to receive(:update_inline_comment).with(
          id:   123,
          body: inline_comments[0].body
        )

        expect(pull_request).to receive(:add_comment_on_lines).with(
          commit_id:  commit_sha,
          path:       "app/controllers/users_controller.rb",
          start_line: 10,
          line:       15,
          body:       inline_comments[1].body
        )

        poster.call
      end
    end

    context "when all comments already exist" do
      let(:first_existing_comment) do
        instance_double(Comment, id: 123, body: "<!-- coverage-inline-marker -->\nfoo", start_line: 5, line: 5, path: "app/models/user.rb")
      end
      let(:second_existing_comment) do
        instance_double(
          Comment,
          id:         456,
          body:       "<!-- coverage-inline-marker -->\nbar",
          start_line: 10,
          line:       15,
          path:       "app/controllers/users_controller.rb"
        )
      end

      before do
        allow(pull_request).to receive(:inline_comments).and_return([first_existing_comment, second_existing_comment])
        allow(pull_request).to receive(:update_inline_comment)
        allow(pull_request).to receive(:delete_inline_comment)
      end

      it "updates all existing comments" do
        expect(pull_request).to receive(:update_inline_comment).with(
          id:   123,
          body: inline_comments[0].body
        )

        expect(pull_request).to receive(:update_inline_comment).with(
          id:   456,
          body: inline_comments[1].body
        )

        poster.call
      end
    end

    context "with empty comment list" do
      let(:inline_comments) { [] }

      before do
        allow(pull_request).to receive(:inline_comments).and_return([])
        allow(pull_request).to receive(:delete_inline_comment)
      end

      it "does not call any pull request methods except for recording existing comments" do
        expect(pull_request).to receive(:inline_comments).once
        expect(pull_request).not_to receive(:add_comment_on_lines)
        expect(pull_request).not_to receive(:update_inline_comment)

        poster.call
      end
    end

    it "logs information for each comment" do
      allow(pull_request).to receive(:inline_comments).and_return([])
      allow(pull_request).to receive(:add_comment_on_lines)
      allow(pull_request).to receive(:delete_inline_comment)

      # Mock the logger to capture all log messages without changing global state
      test_logger = instance_double(Logger)
      allow(poster).to receive(:logger).and_return(test_logger)

      expect(test_logger).to receive(:debug).with("Recording existing coverage comments")
      expect(test_logger).to receive(:debug).with("No stale coverage comments to clean up")
      expect(test_logger).to receive(:info).with("Posting inline comment for app/models/user.rb: 5–5")
      expect(test_logger).to receive(:info).with("Posting inline comment for app/controllers/users_controller.rb: 10–15")

      poster.call
    end

    context "when there are existing coverage comments to clean up" do
      let(:existing_comment) do
        instance_double(
          Comment,
          id:         999,
          body:       "<!-- coverage-inline-marker -->\nfoo",
          path:       "app/models/old_file.rb",
          line:       20,
          start_line: 20
        )
      end

      before do
        allow(pull_request).to receive(:inline_comments).and_return([existing_comment])
        allow(pull_request).to receive(:update_inline_comment)
        allow(pull_request).to receive(:add_comment_on_lines)
        allow(pull_request).to receive(:delete_inline_comment)
      end

      it "deletes unused coverage comments" do
        expect(pull_request).to receive(:delete_inline_comment).with(999)

        poster.call
      end

      it "logs cleanup information" do
        # Mock the logger to capture all log messages without changing global state
        test_logger = instance_double(Logger)
        allow(poster).to receive(:logger).and_return(test_logger)

        expect(test_logger).to receive(:debug).with("Recording existing coverage comments")
        expect(test_logger).to receive(:debug).with("Found existing coverage comment: 999 for app/models/old_file.rb:20-20")
        expect(test_logger).to receive(:debug).with("Cleaning up 1 unused coverage comments")
        expect(test_logger).to receive(:info).with("Posting inline comment for app/models/user.rb: 5–5")
        expect(test_logger).to receive(:info).with("Posting inline comment for app/controllers/users_controller.rb: 10–15")
        expect(test_logger).to receive(:info).with("Deleting stale coverage comment: 999")

        poster.call
      end
    end

    context "when there are no existing coverage comments to clean up" do
      let(:existing_comment) { instance_double(Comment, id: 123) }

      before do
        allow(pull_request).to receive(:inline_comments).and_return([])
        allow(pull_request).to receive(:update_inline_comment)
        allow(pull_request).to receive(:add_comment_on_lines)
        allow(pull_request).to receive(:delete_inline_comment)
      end

      it "does not delete any comments" do
        expect(pull_request).not_to receive(:delete_inline_comment)

        poster.call
      end

      it "logs that no cleanup is needed" do
        # Mock the logger to capture all log messages without changing global state
        test_logger = instance_double(Logger)
        allow(poster).to receive(:logger).and_return(test_logger)

        # Allow info messages (they're logged for each comment)
        allow(test_logger).to receive(:info)

        expect(test_logger).to receive(:debug).with("Recording existing coverage comments")
        expect(test_logger).to receive(:debug).with("No stale coverage comments to clean up")

        poster.call
      end
    end
  end
end
