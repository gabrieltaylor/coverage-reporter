# frozen_string_literal: true

require "spec_helper"

RSpec.describe CoverageReporter::Options do
  describe ".parse" do
    context "when overriding all options via CLI args" do
      it "applies the overrides" do
        args = [
          "--coverage-path",
          "cov/merged.json",
          "--html-root",
          "cov/html",
          "--build-url",
          "https://ci.other/build/999",
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
          coverage_path: "cov/merged.json",
          html_root:     "cov/html",
          build_url:     "https://ci.other/build/999",
          github_token:  "cli-token",
          commit_sha:    "abc123",
          pr_number:     "42",
          repo:          "owner/repo"
        )
      end
    end

    context "when github token provided via CLI but not in defaults" do
      it "succeeds and sets the token" do
        result = described_class.parse(["--github-token", "supplied"])
        expect(result[:github_token]).to eq("supplied")
        expect(result[:build_url]).to eq("www.example.com/builds/123")
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
          described_class.parse(["--help", "--coverage-path", "ignored"])
        end.to raise_error(SystemExit) { |e|
          expect(e.status).to eq(0)
        }
      end
    end

    context "immutability / independence of returned hash" do
      it "returns a new hash (mutating result does not change defaults)" do
        result = described_class.parse(["--github-token", "test"])
        result[:coverage_path] = "changed"

        again = described_class.parse(["--github-token", "test"])
        expect(again[:coverage_path]).to eq("coverage/coverage.json")
      end
    end

    context "when defaults provide token with surrounding whitespace" do
      it "accepts after stripping without error" do
        expect { described_class.parse(["--github-token", "  test  "]) }.not_to raise_error
      end
    end
  end

  describe ".validate!" do
    it "does nothing when github_token present" do
      opts = { github_token: "token" }
      expect { described_class.validate!(opts) }.not_to raise_error
    end

    it "aborts when github_token blank string" do
      opts = { github_token: "" }
      expect do
        described_class.validate!(opts)
      end.to raise_error(SystemExit) { |e|
        expect(e.message).to include("--github-token or $GITHUB_TOKEN")
      }
    end

    it "aborts when github_token nil" do
      opts = { github_token: nil }
      expect { described_class.validate!(opts) }.to raise_error(SystemExit)
    end
  end
end
