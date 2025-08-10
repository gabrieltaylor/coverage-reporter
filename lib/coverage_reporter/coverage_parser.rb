# frozen_string_literal: true

require "json"

module CoverageReporter
  class CoverageParser
    def initialize(resultset_path)
      @resultset_path = resultset_path
    end

    def call
      raw = read_json
      return {} unless raw.is_a?(Hash)

      aggregate = Hash.new { |h, k| h[k] = [] }

      raw.each_value do |entry|
        next unless entry.is_a?(Hash)

        coverage_hash = extract_coverage_hash(entry)
        next unless coverage_hash

        coverage_hash.each do |file, line_data|
          covered_lines = extract_covered_lines(line_data)
          aggregate[file] |= covered_lines # set-union to avoid duplicates
        end
      end

      aggregate
    end

    private

    def read_json
      return {} unless File.file?(@resultset_path)

      content = File.read(@resultset_path)
      JSON.parse(content)
    rescue StandardError
      {}
    end

    def extract_coverage_hash(entry)
      if entry["coverage"].is_a?(Hash)
        entry["coverage"]
      elsif entry["files"].is_a?(Array)
        entry["files"].each_with_object({}) do |f, acc|
          next unless f.is_a?(Hash) && f["filename"] && f["coverage"].is_a?(Array)

          acc[f["filename"]] = f["coverage"]
        end
      end
    end

    def extract_covered_lines(line_data)
      case line_data
      when Array
        array_covered_lines(line_data)
      when Hash
        if line_data["lines"].is_a?(Array)
          array_covered_lines(line_data["lines"])
        else
          hash_covered_lines(line_data)
        end
      else
        []
      end
    end

    def array_covered_lines(arr)
      covered = []
      arr.each_with_index do |count, idx|
        covered << (idx + 1) if count.to_i.positive?
      end
      covered
    end

    def hash_covered_lines(hash)
      hash.each_with_object([]) do |(k, v), acc|
        line_no = k.to_i
        acc << line_no if line_no.positive? && v.to_i.positive?
      end.sort
    end
  end
end
