# frozen_string_literal: true

require "optparse"

module CoverageReporter
  module Options
    class Collate < Base
      def self.defaults
        {
          coverage_dir:  "coverage",
          modified_only: false,
          github_token:  ENV.fetch("GITHUB_TOKEN", nil),
          repo:          ENV.fetch("REPO", nil),
          pr_number:     ENV.fetch("PR_NUMBER", nil)
        }
      end

      def self.parse(argv)
        opts = defaults.dup
        parser = build_parser(opts)
        parser.parse!(argv)
        opts
      end

      # rubocop:disable Metrics/MethodLength
      def self.build_parser(opts)
        OptionParser.new do |o|
          o.banner = "Usage: coverage-reporter collate [options]"
          o.on("--coverage-dir DIR", "Directory containing coverage files (default: coverage)") do |v|
            opts[:coverage_dir] = v
          end
          o.on("--modified-only", "Filter to only modified files") do
            opts[:modified_only] = true
          end
          o.on("--github-token TOKEN", "GitHub token") do |v|
            opts[:github_token] = v
          end
          o.on("--repo REPO", "Repository") do |v|
            opts[:repo] = v
          end
          o.on("--pr-number PR_NUMBER", "Pull request number") do |v|
            opts[:pr_number] = v
          end
          o.on_tail("-h", "--help", "Show help") do
            puts o
            exit 0
          end
        end
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
