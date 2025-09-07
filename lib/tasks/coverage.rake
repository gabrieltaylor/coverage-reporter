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
      html_root: "coverage",
      github_token: ENV["GITHUB_TOKEN"],
      build_url: ENV["BUILDKITE_BUILD_URL"],
      base_ref: ENV["BUILDKITE_BASE_REF"]
    }
    CoverageReporter::Runner.new(options).run
  end
end
