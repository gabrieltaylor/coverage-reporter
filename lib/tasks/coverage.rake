# frozen_string_literal: true

namespace :coverage do
  desc "Merge coverage reports and upload artifacts"
  task :collate do
    require "simplecov"
    require "simplecov_json_formatter"

    # Collate JSON coverage reports and generate both HTML and JSON outputs
    files = Dir["coverage/resultset-*.json"]
    abort "No coverage JSON files found to collate" if files.empty?
    puts "Collate coverage files: #{files.join(', ')}"
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
end
