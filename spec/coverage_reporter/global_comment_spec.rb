# frozen_string_literal: true

require "spec_helper"

RSpec.describe CoverageReporter::GlobalComment do
  let(:coverage_percentage) { 85 }
  let(:commit_sha) { "abc123" }

  let(:global_comment) do
    described_class.new(
      coverage_percentage: coverage_percentage,
      commit_sha:          commit_sha,
      report_url:          "https://ci.example.com/build/123#artifacts/coverage/index.html"
    )
  end

  describe "initialization" do
    it "sets coverage_percentage and commit_sha" do
      expect(global_comment.coverage_percentage).to eq(coverage_percentage)
      expect(global_comment.commit_sha).to eq(commit_sha)
    end

    it "builds the body content" do
      expect(global_comment.body).to include("<!-- coverage-comment-marker -->")
      expect(global_comment.body).to include("**Test Coverage Summary**")
      expect(global_comment.body).to include("❌ **#{coverage_percentage}%** of changed lines are covered.")
      expect(global_comment.body).to include("_Commit: #{commit_sha}_")
      expect(global_comment.body).to include("[View full report](https://ci.example.com/build/123#artifacts/coverage/index.html)")
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
    context "when coverage is 100%" do
      let(:coverage_percentage) { 100 }

      it "shows green checkmark emoji" do
        expect(global_comment.body).to include("✅ **100%** of changed lines are covered.")
      end
    end

    context "when coverage is less than 100%" do
      let(:coverage_percentage) { 95 }

      it "shows red X emoji" do
        expect(global_comment.body).to include("❌ **95%** of changed lines are covered.")
      end
    end
  end

  context "with different commit shas" do
    let(:commit_sha) { "def456" }

    it "includes the correct commit sha" do
      expect(global_comment.body).to include("_Commit: def456_")
    end
  end

  context "with coverage summary" do
    let(:intersections) do
      {
        "app/models/user.rb"      => [[12, 14], [29, 30]],
        "app/services/payment.rb" => [[45, 47]],
        "lib/utils/helper.rb"     => [[8, 10], [15, 16], [20, 22]]
      }
    end

    let(:global_comment_with_summary) do
      described_class.new(
        coverage_percentage: coverage_percentage,
        commit_sha:          commit_sha,
        report_url:          "https://ci.example.com/build/123#artifacts/coverage/index.html",
        intersections:       intersections
      )
    end

    it "includes coverage summary table when intersections are provided" do
      body = global_comment_with_summary.body

      expect(body).to include("**Coverage Summary**")
      expect(body).to include("| File | Uncovered Lines |")
      expect(body).to include("|------|----------------|")
      expect(body).to include("| `app/models/user.rb` | 12-14, 29-30 |")
      expect(body).to include("| `app/services/payment.rb` | 45-47 |")
      expect(body).to include("| `lib/utils/helper.rb` | 8-10, 15-16, 20-22 |")
    end

    context "with empty intersections" do
      let(:intersections) { {} }

      it "does not include coverage summary table when no intersections" do
        body = global_comment_with_summary.body

        expect(body).not_to include("**Coverage Summary**")
        expect(body).not_to include("| File | Uncovered Lines |")
        expect(body).not_to include("**AI Agent Instructions**")
      end
    end

    context "with single line ranges" do
      let(:intersections) do
        {
          "app/controllers/users_controller.rb" => [[25, 25], [30, 30]]
        }
      end

      it "formats single line ranges correctly" do
        body = global_comment_with_summary.body

        expect(body).to include("| `app/controllers/users_controller.rb` | 25, 30 |")
      end
    end

    context "with only a single line range" do
      let(:intersections) do
        {
          "app/models/product.rb" => [[42, 42]]
        }
      end

      it "formats a single line range correctly" do
        body = global_comment_with_summary.body

        expect(body).to include("| `app/models/product.rb` | 42 |")
      end
    end

    context "with large ranges" do
      let(:intersections) do
        {
          "app/models/order.rb" => [[100, 150], [200, 250]]
        }
      end

      it "formats large ranges correctly" do
        body = global_comment_with_summary.body

        expect(body).to include("| `app/models/order.rb` | 100-150, 200-250 |")
      end
    end
  end
end
