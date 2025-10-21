# frozen_string_literal: true

require "spec_helper"
require "coverage_reporter/options/report"

RSpec.describe CoverageReporter::Options::Report do
  describe ".parse" do
    context "when overriding all options via CLI args" do
      it "applies the overrides" do
        args = [
          "--coverage-report-path",
          "cov/merged.json",
          "--report-url",
          "https://ci.other/report/999",
          "--github-token",
          "cli-token",
          "--commit-sha",
          "abc123",
          "--pr-number",
          "42",
          "--repo",
          "owner/repo"
        ]

        result = described_class.parse(args)

        expect(result).to include(
          coverage_report_path: "cov/merged.json",
          report_url:           "https://ci.other/report/999",
          github_token:         "cli-token",
          commit_sha:           "abc123",
          pr_number:            "42",
          repo:                 "owner/repo"
        )
      end
    end

    context "when github token provided via CLI but not in defaults" do
      it "succeeds and sets the token" do
        result = described_class.parse(
          [
            "--github-token",
            "supplied",
            "--repo",
            "owner/repo",
            "--pr-number",
            "123",
            "--commit-sha",
            "abc123"
          ]
        )
        expect(result[:github_token]).to eq("supplied")
      end
    end

    context "when help flag -h is provided with no token" do
      it "prints usage and exits 0 before validation" do
        expect(described_class).not_to receive(:validate!)
        expect do
          described_class.parse(["-h"])
        end.to raise_error(SystemExit) { |e|
          expect(e.status).to eq(0)
        }
      end
    end

    context "when help flag --help is provided with other arguments" do
      it "prints usage and exits 0 early" do
        expect(described_class).not_to receive(:validate!)
        expect do
          described_class.parse(["--help", "--coverage-report-path", "ignored"])
        end.to raise_error(SystemExit) { |e|
          expect(e.status).to eq(0)
        }
      end
    end

    context "immutability / independence of returned hash" do
      it "returns a new hash (mutating result does not change defaults)" do
        result = described_class.parse(["--github-token", "test", "--repo", "owner/repo", "--pr-number", "123", "--commit-sha", "abc123"])
        result[:coverage_report_path] = "changed"

        again = described_class.parse(["--github-token", "test", "--repo", "owner/repo", "--pr-number", "123", "--commit-sha", "abc123"])
        expect(again[:coverage_report_path]).to eq("coverage/coverage.json")
      end
    end

    context "when defaults provide token with surrounding whitespace" do
      it "accepts after stripping without error" do
        expect do
          described_class.parse(
            [
              "--github-token",
              "  test  ",
              "--repo",
              "owner/repo",
              "--pr-number",
              "123",
              "--commit-sha",
              "abc123"
            ]
          )
        end.not_to raise_error
      end
    end

    context "when repo is provided in different formats" do
      let(:required_args) { ["--github-token", "test", "--pr-number", "123", "--commit-sha", "abc123"] }

      it "normalizes HTTPS GitHub URLs to owner/repo format" do
        result = described_class.parse(required_args + ["--repo", "https://github.com/owner/repo"])
        expect(result[:repo]).to eq("owner/repo")
      end

      it "normalizes HTTPS GitHub URLs with .git suffix to owner/repo format" do
        result = described_class.parse(required_args + ["--repo", "https://github.com/owner/repo.git"])
        expect(result[:repo]).to eq("owner/repo")
      end

      it "normalizes SSH GitHub URLs to owner/repo format" do
        result = described_class.parse(required_args + ["--repo", "git@github.com:owner/repo"])
        expect(result[:repo]).to eq("owner/repo")
      end

      it "normalizes SSH GitHub URLs with .git suffix to owner/repo format" do
        result = described_class.parse(required_args + ["--repo", "git@github.com:owner/repo.git"])
        expect(result[:repo]).to eq("owner/repo")
      end

      it "leaves owner/repo format unchanged" do
        result = described_class.parse(required_args + ["--repo", "owner/repo"])
        expect(result[:repo]).to eq("owner/repo")
      end

      it "handles URLs with extra whitespace" do
        result = described_class.parse(required_args + ["--repo", "  https://github.com/owner/repo  "])
        expect(result[:repo]).to eq("owner/repo")
      end
    end

    context "when repo is provided via environment variable" do
      around do |example|
        original_repo = ENV.fetch("REPO", nil)
        example.run
        ENV["REPO"] = original_repo
      end

      it "normalizes HTTPS GitHub URLs from environment variable" do
        ENV["REPO"] = "https://github.com/owner/repo"
        result = described_class.parse(["--github-token", "test", "--pr-number", "123", "--commit-sha", "abc123"])
        expect(result[:repo]).to eq("owner/repo")
      end

      it "normalizes SSH GitHub URLs from environment variable" do
        ENV["REPO"] = "git@github.com:owner/repo.git"
        result = described_class.parse(["--github-token", "test", "--pr-number", "123", "--commit-sha", "abc123"])
        expect(result[:repo]).to eq("owner/repo")
      end

      it "leaves owner/repo format from environment variable unchanged" do
        ENV["REPO"] = "owner/repo"
        result = described_class.parse(["--github-token", "test", "--pr-number", "123", "--commit-sha", "abc123"])
        expect(result[:repo]).to eq("owner/repo")
      end
    end
  end

  describe ".validate!" do
    let(:valid_opts) do
      {
        github_token: "token",
        repo:         "owner/repo",
        pr_number:    "123",
        commit_sha:   "abc123"
      }
    end

    it "does nothing when all required options present" do
      expect { described_class.validate!(valid_opts) }.not_to raise_error
    end

    it "aborts when github_token missing" do
      opts = valid_opts.merge(github_token: "")
      expect do
        described_class.validate!(opts)
      end.to raise_error(SystemExit) { |e|
        expect(e.message).to include("--github-token or $GITHUB_TOKEN")
      }
    end

    it "aborts when repo missing" do
      opts = valid_opts.merge(repo: "")
      expect do
        described_class.validate!(opts)
      end.to raise_error(SystemExit) { |e|
        expect(e.message).to include("--repo or $REPO")
      }
    end

    it "aborts when pr_number missing" do
      opts = valid_opts.merge(pr_number: "")
      expect do
        described_class.validate!(opts)
      end.to raise_error(SystemExit) { |e|
        expect(e.message).to include("--pr-number or $PR_NUMBER")
      }
    end

    it "aborts when commit_sha missing" do
      opts = valid_opts.merge(commit_sha: "")
      expect do
        described_class.validate!(opts)
      end.to raise_error(SystemExit) { |e|
        expect(e.message).to include("--commit-sha or $COMMIT_SHA")
      }
    end

    it "aborts with multiple missing options" do
      opts = valid_opts.merge(github_token: "", repo: "")
      expect do
        described_class.validate!(opts)
      end.to raise_error(SystemExit) { |e|
        expect(e.message).to include("--github-token or $GITHUB_TOKEN")
        expect(e.message).to include("--repo or $REPO")
      }
    end

    it "handles nil values" do
      opts = valid_opts.merge(github_token: nil, repo: nil)
      expect { described_class.validate!(opts) }.to raise_error(SystemExit)
    end
  end
end
