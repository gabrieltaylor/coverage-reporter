# frozen_string_literal: true

require "optparse"

module CoverageReporter
  class Options
    DEFAULTS = {
      build_url:     ENV.fetch("BUILD_URL", nil),
      commit_sha:    ENV.fetch("COMMIT_SHA", nil),
      coverage_path: ENV.fetch("COVERAGE_PATH", "coverage/coverage.json"),
      github_token:  ENV.fetch("GITHUB_TOKEN", nil),
      html_root:     ENV.fetch("HTML_ROOT", "coverage"),
      pr_number:     ENV.fetch("PR_NUMBER", nil),
      repo:          ENV.fetch("REPO", nil)
    }.freeze

    # rubocop:disable Metrics/AbcSize
    # rubocop:disable Metrics/MethodLength
    # rubocop:disable Metrics/BlockLength
    def self.parse(argv)
      opts = DEFAULTS.dup

      parser = OptionParser.new do |o|
        o.banner = "Usage: coverage-reporter [options]"
        o.on("--build-url URL", "CI build URL used for links (default: $BUILD_URL)") do |v|
          opts[:build_url] = v
        end
        o.on("--commit-sha SHA", "GitHub commit SHA (default: $COMMIT_SHA)") do |v|
          opts[:commit_sha] = v
        end
        o.on(
          "--coverage-path PATH",
          "Path to merged SimpleCov coverage.json (default: coverage/coverage.json)"
        ) do |v|
          opts[:coverage_path] = v
        end
        o.on("--github-token TOKEN", "GitHub token (default: $GITHUB_TOKEN)") { |v| opts[:github_token] = v }
        o.on("--html-root PATH", "Root of HTML coverage report (default: coverage)") do |v|
          opts[:html_root] = v
        end
        o.on("--pr-number NUMBER", "GitHub pull request number (default: $PR_NUMBER)") do |v|
          opts[:pr_number] = v
        end
        o.on("--repo REPO", "GitHub repository (default: $REPO)") do |v|
          opts[:repo] = v
        end
        o.on_tail("-h", "--help", "Show help") do
          puts o
          exit 0
        end
      end
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/BlockLength

      parser.parse!(argv)

      validate!(opts)
      opts
    end

    def self.validate!(opts)
      missing = []
      missing << "--github-token or $GITHUB_TOKEN" if opts[:github_token].to_s.strip.empty?
      return unless missing.any?

      abort "coverage_reporter: missing required option(s): #{missing.join(', ')}"
    end
  end
end
