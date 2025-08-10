# frozen_string_literal: true

require "spec_helper"
require "coverage_reporter/comment_poster"

RSpec.describe CoverageReporter::CommentPoster do
  subject(:poster) { described_class.new(pull_request:, stats:) }

  let(:pull_request) { instance_double(CoverageReporter::PullRequest) }
  let(:diff_coverage) { 87.5 }
  let(:uncovered) do
    {
      "app/models/user.rb" => [10, 11, 12, 20, 22, 21, 30],
      "lib/foo.rb"         => [5]
    }
  end
  let(:stats) { double("Stats", uncovered: uncovered, diff_coverage: diff_coverage) }

  before do
    allow(pull_request).to receive(:inline_comments).and_return([])
    allow(pull_request).to receive(:global_comments).and_return([])
    allow(github).to receive(:add_comment_on_lines).and_return("comment_id")
    allow(github).to receive(:add_comment).and_return("comment_id")
  end

  describe "#post_all" do
    it "deletes old inline comments, posts grouped inline comments and a global summary" do
      # Set up coverage link stubs
      allow(github).to receive(:coverage_link_for) do |file, line|
        "https://example.com/coverage/#{file}#L#{line}"
      end
      allow(github).to receive(:coverage_index_link).and_return("https://example.com/coverage/index.html")

      # For user.rb we expect 3 chunks: [10,11,12], [20,21,22], [30]
      expect(github).to receive(:comment_on_line) do |pr, file, line, message|
        expect(pr).to eq(pr_number)
        expect(file).to eq("app/models/user.rb")
        expect(line).to eq(10)
        expect(message).to include("❌ Lines 10–12 are not covered by tests.")
        expect(message).to include("📊 [View coverage](https://example.com/coverage/app/models/user.rb#L10)")
      end.ordered

      expect(github).to receive(:comment_on_line) do |_, file, line, message|
        expect(file).to eq("app/models/user.rb")
        expect(line).to eq(20)
        expect(message).to include("❌ Lines 20–22 are not covered by tests.")
      end.ordered

      expect(github).to receive(:comment_on_line) do |_, file, line, message|
        expect(file).to eq("app/models/user.rb")
        expect(line).to eq(30)
        expect(message).to include("❌ Line 30 is not covered by tests.")
      end.ordered

      # For lib/foo.rb single chunk [5]
      expect(github).to receive(:comment_on_line) do |_, file, line, message|
        expect(file).to eq("lib/foo.rb")
        expect(line).to eq(5)
        expect(message).to include("❌ Line 5 is not covered by tests.")
        expect(message).to include("📊 [View coverage](https://example.com/coverage/lib/foo.rb#L5)")
      end.ordered

      expect(github).to receive(:post_or_update_global_comment) do |pr, body|
        expect(pr).to eq(pr_number)
        expect(body).to include("<!-- coverage-comment-marker -->")
        expect(body).to include("✅ **#{diff_coverage}%** of changed lines are covered.")
      end.ordered

      poster.post_all
    end
  end

  describe "inline grouping edge cases" do
    let(:uncovered) { { "lib/edge.rb" => [3, 3, 4] } }

    it "groups duplicates into separate chunks according to contiguous rule" do
      allow(github).to receive_messages(coverage_link_for: "https://example.com/coverage/link", coverage_index_link: "https://example.com/coverage/index.html")

      # Expect two comments: [3] and [3,4]
      expect(github).to receive(:comment_on_line) do |_, file, line, message|
        expect(file).to eq("lib/edge.rb")
        expect(line).to eq(3)
        expect(message).to include("❌ Line 3 is not covered by tests.")
      end.ordered

      expect(github).to receive(:comment_on_line) do |_, file, line, message|
        expect(file).to eq("lib/edge.rb")
        expect(line).to eq(3) # start of second chunk
        expect(message).to include("❌ Lines 3–4 are not covered by tests.")
      end.ordered

      expect(github).to receive(:post_or_update_global_comment)

      poster.post_all
    end
  end
end
