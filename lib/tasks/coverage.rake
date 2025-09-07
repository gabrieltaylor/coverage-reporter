# frozen_string_literal: true

namespace :coverage do
  desc "Merge coverage reports and upload artifacts"
  task :merge do
    require "simplecov"
    require "simplecov_json_formatter"

    # Collate JSON coverage reports and generate both HTML and JSON outputs
    files = Dir["coverage/resultset-*.json"]
    abort "No coverage JSON files found to collate" if files.empty?
    puts "Collating coverage files: #{files.join(', ')}"
    SimpleCov.collate(files) do
      formatter SimpleCov::Formatter::MultiFormatter.new(
        [
          SimpleCov::Formatter::HTMLFormatter,
          SimpleCov::Formatter::JSONFormatter
        ]
      )
    end

    puts "✅ Coverage merged and report generated."
  end

  desc "Report coverage to GitHub"
  task :report do
    require "coverage_reporter"
    options = {
      coverage_path: "coverage/coverage.json",
      html_root:     "coverage",
      github_token:  ENV.fetch("GITHUB_TOKEN", nil),
      build_url:     ENV.fetch("BUILDKITE_BUILD_URL", nil),
      base_ref:      ENV.fetch("BUILDKITE_BASE_REF", nil),
      commit_sha:    ENV.fetch("BUILDKITE_COMMIT_SHA", nil),
      repo:          ENV.fetch("BUILDKITE_REPO", nil),
      pr_number:     ENV.fetch("BUILDKITE_PULL_REQUEST_NUMBER", nil)
    }

    CoverageReporter::Runner.new(options).run
  end
end
