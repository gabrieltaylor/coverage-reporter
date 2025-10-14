# frozen_string_literal: true

require "spec_helper"

RSpec.describe CoverageReporter::GlobalCommentPoster do
  let(:pull_request) { instance_double(CoverageReporter::PullRequest) }
  let(:poster) { described_class.new(pull_request: pull_request, global_comment: global_comment) }

  let(:global_comment) do
    CoverageReporter::GlobalComment.new(
      coverage_percentage: "85",
      commit_sha:          "abc123"
    )
  end

  describe "#call" do
    context "when no global comment exists" do
      before do
        allow(pull_request).to receive(:global_comments).and_return([])
        allow(pull_request).to receive(:add_global_comment)
      end

      it "adds a new global comment" do
        expect(pull_request).to receive(:add_global_comment).with(
          body: global_comment.body
        )

        poster.call
      end
    end

    context "when a global comment already exists" do
      let(:existing_comment) { instance_double(Comment, id: 123, body: "<!-- coverage-comment-marker -->\nold body") }

      before do
        allow(pull_request).to receive(:global_comments).and_return([existing_comment])
        allow(pull_request).to receive(:update_global_comment)
      end

      it "updates the existing global comment" do
        expect(pull_request).to receive(:update_global_comment).with(
          id:   123,
          body: global_comment.body
        )

        poster.call
      end
    end

    context "when global comment body already includes marker" do
      before do
        allow(pull_request).to receive(:global_comments).and_return([])
        allow(pull_request).to receive(:add_global_comment)
      end

      it "uses the body as-is without adding duplicate marker" do
        expect(pull_request).to receive(:add_global_comment).with(
          body: global_comment.body
        )

        poster.call
      end
    end

    context "when multiple global comments exist but none have the marker" do
      let(:first_comment) { instance_double(Comment, id: 1, body: "comment 1") }
      let(:second_comment) { instance_double(Comment, id: 2, body: "comment 2") }

      before do
        allow(pull_request).to receive(:global_comments).and_return([first_comment, second_comment])
        allow(pull_request).to receive(:add_global_comment)
      end

      it "adds a new global comment" do
        expect(pull_request).to receive(:add_global_comment).with(
          body: global_comment.body
        )

        poster.call
      end
    end
  end

  describe "GLOBAL_COMMENT_MARKER constant" do
    it "has the correct marker value" do
      expect(CoverageReporter::GLOBAL_COMMENT_MARKER).to eq("<!-- coverage-comment-marker -->")
    end
  end
end
