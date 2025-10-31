# frozen_string_literal: true

require "spec_helper"
require "coverage_reporter/options/collate"

RSpec.describe CoverageReporter::Options::Collate do
  describe ".parse" do
    context "when using default options" do
      around do |example|
        original_github_token = ENV.fetch("GITHUB_TOKEN", nil)
        original_repo = ENV.fetch("REPO", nil)
        original_pr_number = ENV.fetch("PR_NUMBER", nil)
        ENV.delete("GITHUB_TOKEN")
        ENV.delete("REPO")
        ENV.delete("PR_NUMBER")
        example.run
        ENV["GITHUB_TOKEN"] = original_github_token if original_github_token
        ENV["REPO"] = original_repo if original_repo
        ENV["PR_NUMBER"] = original_pr_number if original_pr_number
      end

      it "returns default options" do
        result = described_class.parse([])
        expect(result).to eq(
          coverage_dir: "coverage",
          modified_only: false,
          github_token: nil,
          repo: nil,
          pr_number: nil
        )
      end
    end

    context "when overriding all options via CLI args" do
      around do |example|
        original_github_token = ENV.fetch("GITHUB_TOKEN", nil)
        original_repo = ENV.fetch("REPO", nil)
        original_pr_number = ENV.fetch("PR_NUMBER", nil)
        ENV.delete("GITHUB_TOKEN")
        ENV.delete("REPO")
        ENV.delete("PR_NUMBER")
        example.run
        ENV["GITHUB_TOKEN"] = original_github_token if original_github_token
        ENV["REPO"] = original_repo if original_repo
        ENV["PR_NUMBER"] = original_pr_number if original_pr_number
      end

      it "applies the overrides" do
        args = [
          "--coverage-dir",
          "custom/coverage",
          "--modified-only",
          "--github-token",
          "cli-token",
          "--repo",
          "owner/repo",
          "--pr-number",
          "42"
        ]

        result = described_class.parse(args)

        expect(result).to include(
          coverage_dir: "custom/coverage",
          modified_only: true,
          github_token: "cli-token",
          repo: "owner/repo",
          pr_number: "42"
        )
      end
    end

    context "when overriding coverage_dir via CLI args" do
      around do |example|
        original_github_token = ENV.fetch("GITHUB_TOKEN", nil)
        original_repo = ENV.fetch("REPO", nil)
        original_pr_number = ENV.fetch("PR_NUMBER", nil)
        ENV.delete("GITHUB_TOKEN")
        ENV.delete("REPO")
        ENV.delete("PR_NUMBER")
        example.run
        ENV["GITHUB_TOKEN"] = original_github_token if original_github_token
        ENV["REPO"] = original_repo if original_repo
        ENV["PR_NUMBER"] = original_pr_number if original_pr_number
      end

      it "applies the override" do
        result = described_class.parse(["--coverage-dir", "custom/coverage"])
        expect(result[:coverage_dir]).to eq("custom/coverage")
        expect(result[:modified_only]).to eq(false)
      end
    end

    context "when modified-only flag is provided" do
      around do |example|
        original_github_token = ENV.fetch("GITHUB_TOKEN", nil)
        original_repo = ENV.fetch("REPO", nil)
        original_pr_number = ENV.fetch("PR_NUMBER", nil)
        ENV.delete("GITHUB_TOKEN")
        ENV.delete("REPO")
        ENV.delete("PR_NUMBER")
        example.run
        ENV["GITHUB_TOKEN"] = original_github_token if original_github_token
        ENV["REPO"] = original_repo if original_repo
        ENV["PR_NUMBER"] = original_pr_number if original_pr_number
      end

      it "sets modified_only to true" do
        result = described_class.parse(["--modified-only"])
        expect(result[:modified_only]).to eq(true)
      end
    end

    context "when options are provided via environment variables" do
      around do |example|
        original_github_token = ENV.fetch("GITHUB_TOKEN", nil)
        original_repo = ENV.fetch("REPO", nil)
        original_pr_number = ENV.fetch("PR_NUMBER", nil)
        example.run
        ENV["GITHUB_TOKEN"] = original_github_token if original_github_token
        ENV["REPO"] = original_repo if original_repo
        ENV["PR_NUMBER"] = original_pr_number if original_pr_number
      end

      it "uses environment variables as defaults" do
        ENV["GITHUB_TOKEN"] = "env-token"
        ENV["REPO"] = "env/owner-repo"
        ENV["PR_NUMBER"] = "123"

        result = described_class.parse([])

        expect(result).to include(
          github_token: "env-token",
          repo: "env/owner-repo",
          pr_number: "123"
        )
      end

      it "allows CLI args to override environment variables" do
        ENV["GITHUB_TOKEN"] = "env-token"
        ENV["REPO"] = "env/repo"
        ENV["PR_NUMBER"] = "123"

        result = described_class.parse([
          "--github-token",
          "cli-token",
          "--repo",
          "cli/repo",
          "--pr-number",
          "456"
        ])

        expect(result).to include(
          github_token: "cli-token",
          repo: "cli/repo",
          pr_number: "456"
        )
      end
    end

    context "when help flag -h is provided" do
      it "prints usage and exits 0" do
        expect do
          described_class.parse(["-h"])
        end.to raise_error(SystemExit) { |e|
          expect(e.status).to eq(0)
        }
      end
    end

    context "when help flag --help is provided" do
      it "prints usage and exits 0" do
        expect do
          described_class.parse(["--help"])
        end.to raise_error(SystemExit) { |e|
          expect(e.status).to eq(0)
        }
      end
    end

    context "immutability / independence of returned hash" do
      around do |example|
        original_github_token = ENV.fetch("GITHUB_TOKEN", nil)
        original_repo = ENV.fetch("REPO", nil)
        original_pr_number = ENV.fetch("PR_NUMBER", nil)
        ENV.delete("GITHUB_TOKEN")
        ENV.delete("REPO")
        ENV.delete("PR_NUMBER")
        example.run
        ENV["GITHUB_TOKEN"] = original_github_token if original_github_token
        ENV["REPO"] = original_repo if original_repo
        ENV["PR_NUMBER"] = original_pr_number if original_pr_number
      end

      it "returns a new hash (mutating result does not change defaults)" do
        result = described_class.parse(["--coverage-dir", "custom"])
        result[:coverage_dir] = "changed"

        again = described_class.parse(["--coverage-dir", "custom"])
        expect(again[:coverage_dir]).to eq("custom")
      end
    end
  end

  describe ".defaults" do
    around do |example|
      original_github_token = ENV.fetch("GITHUB_TOKEN", nil)
      original_repo = ENV.fetch("REPO", nil)
      original_pr_number = ENV.fetch("PR_NUMBER", nil)
      ENV.delete("GITHUB_TOKEN")
      ENV.delete("REPO")
      ENV.delete("PR_NUMBER")
      example.run
      ENV["GITHUB_TOKEN"] = original_github_token if original_github_token
      ENV["REPO"] = original_repo if original_repo
      ENV["PR_NUMBER"] = original_pr_number if original_pr_number
    end

    it "returns the default options" do
      expect(described_class.defaults).to eq(
        coverage_dir: "coverage",
        modified_only: false,
        github_token: nil,
        repo: nil,
        pr_number: nil
      )
    end

    context "when environment variables are set" do
      around do |example|
        ENV["GITHUB_TOKEN"] = "test-token"
        ENV["REPO"] = "test/repo"
        ENV["PR_NUMBER"] = "999"
        example.run
        ENV.delete("GITHUB_TOKEN")
        ENV.delete("REPO")
        ENV.delete("PR_NUMBER")
      end

      it "includes environment variables in defaults" do
        expect(described_class.defaults).to include(
          github_token: "test-token",
          repo: "test/repo",
          pr_number: "999"
        )
      end
    end
  end
end
