#!/usr/bin/env ruby

# Buildkite-aware RSpec test splitter
#
# Selects a subset of RSpec spec files for the current parallel job and prints
# them (newline-separated). Intended usage:
#
#   bundle exec rspec $(ruby spec/support/test_splitter.rb)
#
# Environment variables used (Buildkite):
# - BUILDKITE_PARALLEL_JOB:        Zero-based index of this parallel job (default: 0)
# - BUILDKITE_PARALLEL_JOB_COUNT:  Total number of parallel jobs (default: 1)
#
# Fallback variables (for other CI environments):
# - CI_NODE_INDEX (index)
# - CI_NODE_TOTAL (count)
#
# Splitting strategy: round-robin by file index to spread tests evenly.

require "pathname"

spec_root     = File.expand_path("..", __dir__)   # .../coverage-reporter/spec
project_root  = File.expand_path("..", spec_root) # .../coverage-reporter

# Discover all spec files, excluding support files and spec_helper
pattern   = File.join(spec_root, "**", "*_spec.rb")

all_specs = Dir.glob(pattern)

# Determine parallel shard info
job_index = ENV.fetch("BUILDKITE_PARALLEL_JOB", ENV.fetch("CI_NODE_INDEX", "0")).to_i
job_count = ENV.fetch("BUILDKITE_PARALLEL_JOB_COUNT", ENV.fetch("CI_NODE_TOTAL", "1")).to_i
job_count = 1 if job_count <= 0
job_index %= job_count

# Select files for this shard (round-robin)
selected = []
all_specs.each_with_index do |path, i|
  selected << path if (i % job_count) == job_index
end

# Output relative paths so RSpec can resolve them from project root
pn_root = Pathname.new(project_root)
selected.each do |abs_path|
  puts Pathname.new(abs_path).relative_path_from(pn_root)
end
