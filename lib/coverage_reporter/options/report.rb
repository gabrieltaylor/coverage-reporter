# frozen_string_literal: true

require "optparse"

module CoverageReporter
  module Options
    class Report < Base
      def self.defaults
        {
          commit_sha:           ENV.fetch("COMMIT_SHA", nil),
          coverage_report_path: ENV.fetch("COVERAGE_REPORT_PATH", "coverage/coverage.json"),
          github_token:         ENV.fetch("GITHUB_TOKEN", nil),
          pr_number:            ENV.fetch("PR_NUMBER", nil),
          repo:                 normalize_repo(ENV.fetch("REPO", nil)),
          report_url:           ENV.fetch("REPORT_URL", nil),
          source_dir:           ENV.fetch("SOURCE_DIR", nil)
        }
      end

      # rubocop:disable Metrics/AbcSize
      # rubocop:disable Metrics/MethodLength
      # rubocop:disable Metrics/BlockLength
      def self.parse(argv)
        opts = defaults.dup

        parser = OptionParser.new do |o|
          o.banner = "Usage: coverage-reporter [options]"
          o.on("--report-url URL", "Report URL used for links (default: $REPORT_URL)") do |v|
            opts[:report_url] = v
          end
          o.on("--commit-sha SHA", "GitHub commit SHA (default: $COMMIT_SHA)") do |v|
            opts[:commit_sha] = v
          end
          o.on(
            "--coverage-report-path PATH",
            "Path to merged SimpleCov coverage.json (default: coverage/coverage.json)"
          ) do |v|
            opts[:coverage_report_path] = v
          end
          o.on("--github-token TOKEN", "GitHub token (default: $GITHUB_TOKEN)") { |v| opts[:github_token] = v }
          o.on("--pr-number NUMBER", "GitHub pull request number (default: $PR_NUMBER)") do |v|
            opts[:pr_number] = v
          end
          o.on("--repo REPO", "GitHub repository (default: $REPO)") do |v|
            opts[:repo] = normalize_repo(v)
          end
          o.on("--source-dir DIR", "Source directory for coverage files (default: $SOURCE_DIR)") do |v|
            opts[:source_dir] = v
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
        missing = collect_missing_options(opts)
        return if missing.empty?

        abort "coverage-reporter: missing required option(s): #{missing.join(', ')}"
      end

      def self.collect_missing_options(opts)
        required_options = {
          github_token: "--github-token or $GITHUB_TOKEN",
          repo:         "--repo or $REPO",
          pr_number:    "--pr-number or $PR_NUMBER",
          commit_sha:   "--commit-sha or $COMMIT_SHA"
        }

        required_options.filter_map do |key, message|
          message if opts[key].to_s.strip.empty?
        end
      end

      def self.normalize_repo(repo)
        return repo if repo.nil? || repo.strip.empty?

        repo.strip
          .gsub(%r{^(https://github\.com/|git@github\.com:)}, "")
          .gsub(/\.git$/, "")
      end
    end
  end
end
