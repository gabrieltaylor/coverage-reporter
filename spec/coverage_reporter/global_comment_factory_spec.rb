# frozen_string_literal: true

require "spec_helper"

RSpec.describe CoverageReporter::GlobalCommentFactory do
  let(:commit_sha) { "abc123" }
  let(:factory) { described_class.new(commit_sha: commit_sha) }

  describe "#call" do
    it "returns a GlobalComment object" do
      global_comment = factory.call

      expect(global_comment).to be_a(CoverageReporter::GlobalComment)
      expect(global_comment.commit_sha).to eq(commit_sha)
    end

    it "sets the coverage percentage" do
      global_comment = factory.call

      expect(global_comment.coverage_percentage).to eq("N/A")
    end

    it "includes proper body content" do
      global_comment = factory.call

      expect(global_comment.body).to include("<!-- coverage-comment-marker -->")
      expect(global_comment.body).to include("🧪 **Test Coverage Summary**")
      expect(global_comment.body).to include("✅ **N/A%** of changed lines are covered.")
      expect(global_comment.body).to include("_Commit: #{commit_sha}_")
    end
  end

  describe "initialization" do
    it "sets commit_sha" do
      expect(factory.instance_variable_get(:@commit_sha)).to eq(commit_sha)
    end
  end

  describe "private methods" do
    describe "#calculate_coverage_percentage" do
      it "returns N/A as placeholder" do
        result = factory.send(:calculate_coverage_percentage)
        expect(result).to eq("N/A")
      end
    end
  end
end
