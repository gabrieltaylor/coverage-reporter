# frozen_string_literal: true

module CoverageReporter
  class Options
    DEFAULTS = {
      coverage_path: "coverage/.resultset.json",
      html_root:     "coverage",
      base_ref:      "origin/main",
      build_url:     ENV.fetch("BUILDKITE_BUILD_URL", nil),
      github_token:  ENV.fetch("GITHUB_TOKEN", nil)
    }.freeze

    # rubocop:disable Metrics/AbcSize
    # rubocop:disable Metrics/MethodLength
    def self.parse(argv)
      opts = DEFAULTS.dup

      parser = OptionParser.new do |o|
        o.banner = "Usage: coverage_commenter [options]"
        o.on(
          "--coverage-path PATH",
          "Path to merged SimpleCov .resultset.json (default: #{DEFAULTS[:coverage_path]})"
        ) do |v|
          opts[:coverage_path] = v
        end
        o.on("--html-root PATH", "Root of HTML coverage report (default: #{DEFAULTS[:html_root]})") do |v|
          opts[:html_root] = v
        end
        o.on("--github-token TOKEN", "GitHub token (default: $GITHUB_TOKEN)") { |v| opts[:github_token] = v }
        o.on("--build-url URL", "CI build URL used for links (default: $BUILDKITE_BUILD_URL)") do |v|
          opts[:build_url] = v
        end
        o.on("--base-ref REF", "Base git ref for diff (default: #{DEFAULTS[:base_ref]})") { |v| opts[:base_ref] = v }
        o.on_tail("-h", "--help", "Show help") do
          puts o
          exit 0
        end
      end
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/MethodLength

      parser.parse!(argv)

      validate!(opts)
      opts
    end

    def self.validate!(opts)
      missing = []
      missing << "--github-token or $GITHUB_TOKEN" if opts[:github_token].to_s.strip.empty?
      # build_url is optional; if absent we still run but links will point to index without CI context
      return unless missing.any?

      abort "coverage_commenter: missing required option(s): #{missing.join(', ')}"
    end
  end
end
