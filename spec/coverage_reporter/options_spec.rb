# frozen_string_literal: true

require "spec_helper"

RSpec.describe CoverageReporter::Options do
  describe ".parse" do
    context "when defaults include token and build_url and no CLI options" do
      xit "returns the defaults" do
        result = described_class.parse([])

        expect(result[:coverage_path]).to eq("coverage/.resultset.json")
        expect(result[:html_root]).to eq("coverage")
        expect(result[:base_ref]).to eq("origin/main")
        expect(result[:build_url]).to eq("https://ci.example/build/123")
        expect(result[:github_token]).to eq("secret-token")
      end
    end

    context "when overriding all options via CLI args" do
      xit "applies the overrides" do
        args = [
          "--coverage-path",
          "cov/merged.json",
          "--html-root",
          "cov/html",
          "--base-ref",
          "upstream/develop",
          "--build-url",
          "https://ci.other/build/999",
          "--github-token",
          "cli-token"
        ]

        result = described_class.parse(args)

        expect(result).to include(
          coverage_path: "cov/merged.json",
          html_root:     "cov/html",
          base_ref:      "upstream/develop",
          build_url:     "https://ci.other/build/999",
          github_token:  "cli-token"
        )
      end
    end

    context "when github token is missing (not provided in defaults or CLI)" do
      xit "aborts with an explanatory message" do
        expect do
          described_class.parse([])
        end.to raise_error(SystemExit) { |e|
          expect(e.status).not_to eq(0)
          expect(e.message).to include("coverage_commenter: missing required option(s): --github-token or $GITHUB_TOKEN")
        }
      end
    end

    context "when github token provided via CLI but not in defaults" do
      xit "succeeds and sets the token" do
        result = described_class.parse(["--github-token", "supplied"])
        expect(result[:github_token]).to eq("supplied")
        expect(result[:build_url]).to be_nil
      end
    end

    context "when help flag -h is provided with no token" do
      xit "prints usage and exits 0 before validation" do
        expect(described_class).not_to receive(:validate!)
        expect do
          described_class.parse(["-h"])
        end.to raise_error(SystemExit) { |e|
          expect(e.status).to eq(0)
        }
      end
    end

    context "when help flag --help is provided with other arguments" do
      xit "prints usage and exits 0 early" do
        expect(described_class).not_to receive(:validate!)
        expect do
          described_class.parse(["--help", "--coverage-path", "ignored"])
        end.to raise_error(SystemExit) { |e|
          expect(e.status).to eq(0)
        }
      end
    end

    context "immutability / independence of returned hash" do
      xit "returns a new hash (mutating result does not change defaults)" do
        result = described_class.parse([])
        result[:coverage_path] = "changed"

        again = described_class.parse([])
        expect(again[:coverage_path]).to eq("coverage/.resultset.json")
      end
    end

    context "when defaults provide token with surrounding whitespace" do
      xit "accepts after stripping without error" do
        expect { described_class.parse([]) }.not_to raise_error
      end
    end
  end

  describe ".validate!" do
    xit "does nothing when github_token present" do
      opts = { github_token: "token" }
      expect { described_class.validate!(opts) }.not_to raise_error
    end

    xit "aborts when github_token blank string" do
      opts = { github_token: "" }
      expect do
        described_class.validate!(opts)
      end.to raise_error(SystemExit) { |e|
        expect(e.message).to include("--github-token or $GITHUB_TOKEN")
      }
    end

    xit "aborts when github_token nil" do
      opts = { github_token: nil }
      expect { described_class.validate!(opts) }.to raise_error(SystemExit)
    end
  end
end
