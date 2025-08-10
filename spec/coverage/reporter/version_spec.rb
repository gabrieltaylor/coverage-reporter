# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Coverage::Reporter::VERSION" do
  it "is defined" do
    expect(defined?(Coverage::Reporter::VERSION)).to eq("constant")
  end

  it "matches semantic versioning (x.y.z)" do
    expect(Coverage::Reporter::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end
end

# Placeholder specs to guide future development.
RSpec.describe "Coverage::Reporter future functionality" do
  describe "CLI (planned)" do
    it "reports coverage to a pull request (pending implementation)" do
      skip "Implement a CLI that parses SimpleCov results and posts a PR comment"
    end

    it "exits with non-zero status when coverage threshold not met (pending)" do
      skip "Add configuration for minimum coverage thresholds and enforce them"
    end

    it "supports dry-run mode (pending)" do
      skip "Implement a flag that outputs the comment body without posting"
    end
  end

  describe "Configuration (planned)" do
    it "allows custom formatter selection (pending)" do
      skip "Support selecting which coverage metrics to include"
    end

    it "reads repo / PR context from environment (pending)" do
      skip "Read GITHUB_REPOSITORY, GITHUB_REF, etc. for GitHub Actions integration"
    end
  end

  describe "Output formatting (planned)" do
    it "renders a markdown summary table (pending)" do
      skip "Generate a table with file coverage deltas"
    end

    it "highlights decreased coverage (pending)" do
      skip "Show visual indicators (emoji / symbols) for decreases"
    end
  end
end
