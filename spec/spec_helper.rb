# frozen_string_literal: true

require "simplecov"
require "simplecov_json_formatter"

# Configure SimpleCov for parallel test execution
if ENV["BUILDKITE_PARALLEL_JOB"]
  # Buildkite parallel execution
  SimpleCov.command_name "RSpec-#{ENV['BUILDKITE_PARALLEL_JOB']}"
  SimpleCov.formatter = SimpleCov::Formatter::JSONFormatter
else
  # Single job execution
  SimpleCov.command_name "RSpec"
  SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new(
    [
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::JSONFormatter
    ]
  )
end

SimpleCov.start

# Require the library under test
require "coverage_reporter"

# Test double class for GitHub API comments
class Comment
  attr_reader :id, :body, :path, :line, :start_line

  def initialize(id:, body:, path: nil, line: nil, start_line: nil)
    @id = id
    @body = body
    @path = path
    @line = line
    @start_line = start_line
  end
end

# If you later add support files (custom matchers, shared contexts, etc.)
# you can keep them in spec/support and uncomment the Dir[] line below.
# Dir[File.join(__dir__, "support", "**", "*.rb")].sort.each { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = "spec/examples.txt"

  # Allow focusing individual examples with :focus metadata
  config.filter_run_when_matching :focus

  # Disable RSpec exposing methods globally on `Object`
  config.disable_monkey_patching!

  # Use the documentation formatter for detailed output when running a single file
  config.default_formatter = "doc" if config.files_to_run.one?

  # Run specs in random order to surface order dependencies
  config.order = :random

  # Seed global randomization in this process using the --seed CLI option
  Kernel.srand config.seed

  # Expectations configuration
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  # Mocking configuration
  config.mock_with :rspec do |mocks|
    # Prevent mocking or stubbing methods that do not exist
    mocks.verify_partial_doubles = true
  end

  # Fail when there are any deprecations (helps keep the gem tidy)
  config.raise_errors_for_deprecations!

  # You can turn this on if you want Ruby warnings shown during spec runs
  # config.warnings = true
end
