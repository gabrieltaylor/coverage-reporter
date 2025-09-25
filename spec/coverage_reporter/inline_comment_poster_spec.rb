# frozen_string_literal: true

require "spec_helper"

RSpec.describe CoverageReporter::InlineCommentPoster do
  let(:pull_request) { instance_double(CoverageReporter::PullRequest) }
  let(:commit_sha) { "abc123" }
  let(:poster) { described_class.new(pull_request: pull_request, commit_sha: commit_sha, inline_comments: inline_comments) }

  let(:inline_comments) do
    [
      CoverageReporter::InlineComment.new(
        file:       "app/models/user.rb",
        start_line: 5,
        end_line:   5,
        message:    "❌ Line 5 is not covered by tests.",
        body:       "<!-- coverage-inline-marker -->\n❌ Line 5 is not covered by tests.\n\n" \
                    "_File: app/models/user.rb, line 5_\n_Commit: abc123_"
      ),
      CoverageReporter::InlineComment.new(
        file:       "app/controllers/users_controller.rb",
        start_line: 10,
        end_line:   15,
        message:    "❌ Lines 10–15 are not covered by tests.",
        body:       "<!-- coverage-inline-marker -->\n❌ Lines 10–15 are not covered by tests.\n\n" \
                    "_File: app/controllers/users_controller.rb, line 10_\n_Commit: abc123_"
      )
    ]
  end

  describe "#call" do
    context "when comments don't exist yet" do
      before do
        allow(pull_request).to receive(:inline_comments).and_return([])
        allow(pull_request).to receive(:find_existing_inline_comment).and_return(nil)
        allow(pull_request).to receive(:add_comment_on_lines)
        allow(pull_request).to receive(:delete_inline_comment)
      end

      it "posts all inline comments" do
        expect(pull_request).to receive(:add_comment_on_lines).with(
          commit_id:  commit_sha,
          file_path:  "app/models/user.rb",
          start_line: 5,
          end_line:   5,
          body:       inline_comments[0].body
        )

        expect(pull_request).to receive(:add_comment_on_lines).with(
          commit_id:  commit_sha,
          file_path:  "app/controllers/users_controller.rb",
          start_line: 10,
          end_line:   15,
          body:       inline_comments[1].body
        )

        poster.call
      end

      it "returns an empty set of updated comment IDs" do
        result = poster.call
        expect(result).to eq(Set.new)
      end
    end

    context "when some comments already exist" do
      let(:existing_comment) { instance_double(Comment, id: 123) }

      before do
        allow(pull_request).to receive(:inline_comments).and_return([])
        allow(pull_request).to receive(:find_existing_inline_comment)
          .with("app/models/user.rb", 5, 5)
          .and_return(existing_comment)
        allow(pull_request).to receive(:find_existing_inline_comment)
          .with("app/controllers/users_controller.rb", 10, 15)
          .and_return(nil)
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
          file_path:  "app/controllers/users_controller.rb",
          start_line: 10,
          end_line:   15,
          body:       inline_comments[1].body
        )

        poster.call
      end

      it "returns the set of updated comment IDs" do
        result = poster.call
        expect(result).to eq(Set.new([123]))
      end
    end

    context "when all comments already exist" do
      let(:first_existing_comment) { instance_double(Comment, id: 123) }
      let(:second_existing_comment) { instance_double(Comment, id: 456) }

      before do
        allow(pull_request).to receive(:inline_comments).and_return([])
        allow(pull_request).to receive(:find_existing_inline_comment)
          .with("app/models/user.rb", 5, 5)
          .and_return(first_existing_comment)
        allow(pull_request).to receive(:find_existing_inline_comment)
          .with("app/controllers/users_controller.rb", 10, 15)
          .and_return(second_existing_comment)
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

      it "returns all updated comment IDs" do
        result = poster.call
        expect(result).to eq(Set.new([123, 456]))
      end
    end

    context "with empty comment list" do
      let(:inline_comments) { [] }

      before do
        allow(pull_request).to receive(:inline_comments).and_return([])
        allow(pull_request).to receive(:delete_inline_comment)
      end

      it "returns an empty set" do
        result = poster.call
        expect(result).to eq(Set.new)
      end

      it "does not call any pull request methods except for recording existing comments" do
        expect(pull_request).to receive(:inline_comments).once
        expect(pull_request).not_to receive(:find_existing_inline_comment)
        expect(pull_request).not_to receive(:add_comment_on_lines)
        expect(pull_request).not_to receive(:update_inline_comment)

        poster.call
      end
    end

    it "logs debug information for each comment" do
      allow(pull_request).to receive(:inline_comments).and_return([])
      allow(pull_request).to receive(:find_existing_inline_comment).and_return(nil)
      allow(pull_request).to receive(:add_comment_on_lines)
      allow(pull_request).to receive(:delete_inline_comment)

      expect(CoverageReporter.logger).to receive(:debug).with("Recording existing coverage comments")
      expect(CoverageReporter.logger).to receive(:debug).with("No unused coverage comments to clean up")
      expect(CoverageReporter.logger).to receive(:debug).with("Posting inline comment for app/models/user.rb: 5–5")
      expect(CoverageReporter.logger).to receive(:debug).with("Posting inline comment for app/controllers/users_controller.rb: 10–15")

      poster.call
    end

    context "when there are existing coverage comments to clean up" do
      let(:existing_coverage_comment) do
        instance_double(Comment, 
          id: 999, 
          body: "<!-- coverage-inline-marker -->\n❌ Line 20 is not covered by tests.",
          path: "app/models/old_file.rb",
          line: 20
        )
      end
      let(:existing_comment) { instance_double(Comment, id: 123) }

      before do
        allow(pull_request).to receive(:inline_comments).and_return([existing_coverage_comment])
        allow(pull_request).to receive(:find_existing_inline_comment)
          .with("app/models/user.rb", 5, 5)
          .and_return(existing_comment)
        allow(pull_request).to receive(:find_existing_inline_comment)
          .with("app/controllers/users_controller.rb", 10, 15)
          .and_return(nil)
        allow(pull_request).to receive(:update_inline_comment)
        allow(pull_request).to receive(:add_comment_on_lines)
        allow(pull_request).to receive(:delete_inline_comment)
      end

      it "deletes unused coverage comments" do
        expect(pull_request).to receive(:delete_inline_comment).with(999)

        poster.call
      end

      it "logs cleanup information" do
        expect(CoverageReporter.logger).to receive(:debug).with("Recording existing coverage comments")
        expect(CoverageReporter.logger).to receive(:debug).with("Found existing coverage comment: 999 for app/models/old_file.rb:20")
        expect(CoverageReporter.logger).to receive(:debug).with("Cleaning up 1 unused coverage comments")
        expect(CoverageReporter.logger).to receive(:debug).with("Deleting unused coverage comment: 999")
        expect(CoverageReporter.logger).to receive(:debug).at_least(:once) # Allow for other debug messages

        poster.call
      end
    end

    context "when there are no existing coverage comments to clean up" do
      let(:existing_comment) { instance_double(Comment, id: 123) }

      before do
        allow(pull_request).to receive(:inline_comments).and_return([])
        allow(pull_request).to receive(:find_existing_inline_comment)
          .with("app/models/user.rb", 5, 5)
          .and_return(existing_comment)
        allow(pull_request).to receive(:find_existing_inline_comment)
          .with("app/controllers/users_controller.rb", 10, 15)
          .and_return(nil)
        allow(pull_request).to receive(:update_inline_comment)
        allow(pull_request).to receive(:add_comment_on_lines)
        allow(pull_request).to receive(:delete_inline_comment)
      end

      it "does not delete any comments" do
        expect(pull_request).not_to receive(:delete_inline_comment)

        poster.call
      end

      it "logs that no cleanup is needed" do
        expect(CoverageReporter.logger).to receive(:debug).with("Recording existing coverage comments")
        expect(CoverageReporter.logger).to receive(:debug).with("No unused coverage comments to clean up")
        expect(CoverageReporter.logger).to receive(:debug).at_least(:once) # Allow for other debug messages

        poster.call
      end
    end
  end

  describe "initialization" do
    it "sets pull_request and commit_sha" do
      expect(poster.instance_variable_get(:@pull_request)).to eq(pull_request)
      expect(poster.instance_variable_get(:@commit_sha)).to eq(commit_sha)
    end
  end
end
