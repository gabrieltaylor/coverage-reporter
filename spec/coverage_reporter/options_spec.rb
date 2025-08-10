# frozen_string_literal: true

require "spec_helper"

RSpec.describe CoverageReporter::Options do
  OPTIONS_FILE = File.expand_path("../../../lib/coverage_reporter/options.rb", __FILE__)

  def reload_options
    if CoverageReporter.const_defined?(:Options, false)
      CoverageReporter.send(:remove_const, :Options)
    end
    load OPTIONS_FILE
  end

  def with_env(temp)
    original = {}
    keys = temp.keys
    keys.each do |k|
      if ENV.key?(k)
        original[k] = ENV[k]
      else
        original[k] = :__missing__
      end
    end

    temp.each do |k, v|
      if v.nil?
        ENV.delete(k)
      else
        ENV[k] = v
      end
    end

    yield
  ensure
    original.each do |k, v|
      if v == :__missing__
        ENV.delete(k)
      else
        ENV[k] = v
      end
    end
  end

  describe ".parse" do
    context "when only required env var (GITHUB_TOKEN) is present and no CLI options" do
      it "returns the defaults including env-derived fields" do
        with_env("GITHUB_TOKEN" => "secret-token", "BUILDKITE_BUILD_URL" => "https://ci.example/build/123") do
            reload_options
            result = CoverageReporter::Options.parse([])

            expect(result[:coverage_path]).to eq("coverage/.resultset.json")
            expect(result[:html_root]).to eq("coverage")
            expect(result[:base_ref]).to eq("origin/main")
            expect(result[:build_url]).to eq("https://ci.example/build/123")
            expect(result[:github_token]).to eq("secret-token")
        end
      end
    end

    context "when overriding all options via CLI args" do
      it "applies the overrides" do
        with_env("GITHUB_TOKEN" => "irrelevant-from-env", "BUILDKITE_BUILD_URL" => "env-build-url") do
          reload_options
          args = [
            "--coverage-path", "cov/merged.json",
            "--html-root", "cov/html",
            "--base-ref", "upstream/develop",
            "--build-url", "https://ci.other/build/999",
            "--github-token", "cli-token"
          ]

          result = CoverageReporter::Options.parse(args)

          expect(result).to include(
            coverage_path: "cov/merged.json",
            html_root: "cov/html",
            base_ref: "upstream/develop",
            build_url: "https://ci.other/build/999",
            github_token: "cli-token"
          )
        end
      end
    end

    context "when github token is missing (neither env nor CLI)" do
      it "aborts with an explanatory message" do
        with_env("GITHUB_TOKEN" => nil, "BUILDKITE_BUILD_URL" => nil) do
          reload_options
          expect {
            CoverageReporter::Options.parse([])
          }.to raise_error(SystemExit) { |e|
            # abort exits non-zero and message includes prefix
            expect(e.status).not_to eq(0)
            expect(e.message).to include("coverage_commenter: missing required option(s): --github-token or $GITHUB_TOKEN")
          }
        end
      end
    end

    context "when github token provided via CLI but not in ENV" do
      it "succeeds" do
        with_env("GITHUB_TOKEN" => nil, "BUILDKITE_BUILD_URL" => nil) do
          reload_options
          result = CoverageReporter::Options.parse(["--github-token", "supplied"])
          expect(result[:github_token]).to eq("supplied")
          # build_url optional; default will be nil (captured from ENV at load time)
          expect(result[:build_url]).to be_nil
        end
      end
    end

    context "when help flag -h is provided with no token" do
      it "exits cleanly (status 0) before validation" do
        with_env("GITHUB_TOKEN" => nil) do
          reload_options
          expect {
            CoverageReporter::Options.parse(["-h"])
          }.to raise_error(SystemExit) { |e|
            expect(e.status).to eq(0)
          }
        end
      end
    end

    context "when help flag --help is provided with other arguments" do
      it "prints usage and exits 0 early" do
        with_env("GITHUB_TOKEN" => nil) do
          reload_options
          expect {
            CoverageReporter::Options.parse(["--help", "--coverage-path", "ignored"])
          }.to raise_error(SystemExit) { |e|
            expect(e.status).to eq(0)
          }
        end
      end
    end

    context "immutability / independence of returned hash" do
      it "returns a new hash (mutating result does not change defaults)" do
        with_env("GITHUB_TOKEN" => "t") do
          reload_options
          result = CoverageReporter::Options.parse([])
          result[:coverage_path] = "changed"

          # Re-parse to ensure defaults unaffected
          again = CoverageReporter::Options.parse([])
          expect(again[:coverage_path]).to eq("coverage/.resultset.json")
        end
      end
    end
  end

  describe ".validate!" do
    it "does nothing when github_token present" do
      with_env("GITHUB_TOKEN" => "token") do
        reload_options
        opts = { github_token: "token" }
        # Should not raise / abort
        expect { CoverageReporter::Options.validate!(opts) }.not_to raise_error
      end
    end

    it "aborts when github_token blank string" do
      with_env("GITHUB_TOKEN" => "") do
        reload_options
        opts = { github_token: "" }
        expect {
          CoverageReporter::Options.validate!(opts)
        }.to raise_error(SystemExit) { |e|
          expect(e.message).to include("--github-token or $GITHUB_TOKEN")
        }
      end
    end

    it "aborts when github_token nil" do
      with_env("GITHUB_TOKEN" => nil) do
        reload_options
        opts = { github_token: nil }
        expect {
          CoverageReporter::Options.validate!(opts)
        }.to raise_error(SystemExit)
      end
    end

    it "accepts tokens with surrounding whitespace after stripping" do
      with_env("GITHUB_TOKEN" => "   padded   ") do
        reload_options
        expect { CoverageReporter::Options.parse([]) }.not_to raise_error
      end
    end
  end
end
