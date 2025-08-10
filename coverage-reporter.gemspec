# frozen_string_literal: true

require_relative "lib/coverage_reporter/version"

Gem::Specification.new do |spec|
  spec.name = "coverage-reporter"
  spec.version = Coverage::Reporter::VERSION
  spec.authors = ["Gabriel Taylor Russ"]
  spec.email = ["gabriel.taylor.russ@gmail.com"]

  spec.summary = "Report SimpleCov generated Coverage to a GitHub Pull Request."
  spec.homepage = "https://github.com/gabrieltaylor/coverage-reporter"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata = {
    "bug_tracker_uri"       => "https://github.com/gabrieltaylor/coverage-reporter/issues",
    "changelog_uri"         => "https://github.com/gabrieltaylor/coverage-reporter/releases",
    "source_code_uri"       => "https://github.com/gabrieltaylor/coverage-reporter",
    "homepage_uri"          => spec.homepage,
    "rubygems_mfa_required" => "true"
  }

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.glob(%w[LICENSE.txt README.md {exe,lib}/**/*]).reject { |f| File.directory?(f) }
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "octokit"
end
