# frozen_string_literal: true

require "spec_helper"
require "coverage/reporter/comment_formatter"

RSpec.describe CoverageReporter::CommentFormatter do
  let(:index_link) { "https://example.com/coverage/index.html" }
  let(:github) { double("Github", coverage_index_link: index_link) }
  subject(:formatter) { described_class.new(github: github) }

  describe "#inline_chunk_message" do
    context "when chunk has a single line" do
      let(:file) { "lib/foo.rb" }
      let(:line) { 42 }
      let(:chunk) { [line] }
      let(:coverage_link) { "https://example.com/coverage/lib/foo.rb#L42" }

      it "renders a singular header and includes the coverage link" do
        expect(github).to receive(:coverage_link_for).with(file, line).and_return(coverage_link)

        message = formatter.inline_chunk_message(file: file, chunk: chunk)

        expect(message).to include("❌ Line 42 is not covered by tests.")
        expect(message).to include("📊 [View coverage](#{coverage_link})")
      end
    end

    context "when chunk has multiple contiguous lines" do
      let(:file) { "app/models/user.rb" }
      let(:chunk) { [3, 4, 5, 6, 7] }
      let(:coverage_link) { "https://example.com/coverage/app/models/user.rb#L3" }

      it "renders a plural header with a range and includes the coverage link" do
        expect(github).to receive(:coverage_link_for).with(file, 3).and_return(coverage_link)

        message = formatter.inline_chunk_message(file: file, chunk: chunk)

        # Note: The formatter uses an en dash (–) between start and finish.
        expect(message).to include("❌ Lines 3–7 are not covered by tests.")
        expect(message).to include("📊 [View coverage](#{coverage_link})")
      end
    end
  end

  describe "#global_summary" do
    it "includes the marker, the percentage value, and the index link" do
      diff_coverage = 87.65
      message = formatter.global_summary(diff_coverage: diff_coverage)

      expect(message).to include("<!-- coverage-comment-marker -->")
      expect(message).to include("✅ **87.65%** of changed lines are covered.")
      expect(message).to include("📊 [View full report](#{index_link})")
      expect(message).to include("🧪 **Test Coverage Summary**")
    end

    it "works with an integer percentage" do
      diff_coverage = 100
      message = formatter.global_summary(diff_coverage: diff_coverage)

      expect(message).to include("✅ **100%** of changed lines are covered.")
    end
  end
end
