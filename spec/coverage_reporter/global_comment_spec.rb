# frozen_string_literal: true

require "spec_helper"

RSpec.describe CoverageReporter::GlobalComment do
  let(:coverage_percentage) { "85" }
  let(:commit_sha) { "abc123" }

  let(:global_comment) do
    described_class.new(
      coverage_percentage: coverage_percentage,
      commit_sha:          commit_sha
    )
  end

  describe "initialization" do
    it "sets coverage_percentage and commit_sha" do
      expect(global_comment.coverage_percentage).to eq(coverage_percentage)
      expect(global_comment.commit_sha).to eq(commit_sha)
    end

    it "builds the body content" do
      expect(global_comment.body).to include("<!-- coverage-comment-marker -->")
      expect(global_comment.body).to include("🧪 **Test Coverage Summary**")
      expect(global_comment.body).to include("✅ **#{coverage_percentage}%** of changed lines are covered.")
      expect(global_comment.body).to include("_Commit: #{commit_sha}_")
    end
  end

  describe "body formatting" do
    it "includes the global marker at the beginning" do
      expect(global_comment.body).to start_with("<!-- coverage-comment-marker -->")
    end

    it "includes proper markdown formatting" do
      expect(global_comment.body).to include("**Test Coverage Summary**")
      expect(global_comment.body).to include("**#{coverage_percentage}%**")
    end

    it "includes commit information" do
      expect(global_comment.body).to include("_Commit: #{commit_sha}_")
    end
  end

  context "with different coverage percentages" do
    let(:coverage_percentage) { "100" }

    it "formats the percentage correctly" do
      expect(global_comment.body).to include("✅ **100%** of changed lines are covered.")
    end
  end

  context "with different commit shas" do
    let(:commit_sha) { "def456" }

    it "includes the correct commit sha" do
      expect(global_comment.body).to include("_Commit: def456_")
    end
  end
end
