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
          normalized_file = normalize_filename(file)
          next unless normalized_file

          covered_lines = extract_covered_lines(line_data)
          aggregate[normalized_file] |= covered_lines # set-union to avoid duplicates
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
      return entry["coverage"] if coverage_hash?(entry)
      return extract_from_files_array(entry["files"]) if files_array?(entry)
      return entry if simplecov_format?(entry)

      nil
    end

    def coverage_hash?(entry)
      entry["coverage"].is_a?(Hash)
    end

    def files_array?(entry)
      entry["files"].is_a?(Array)
    end

    def extract_from_files_array(files)
      files.each_with_object({}) do |f, acc|
        next unless valid_file_entry?(f)

        acc[f["filename"]] = f["coverage"]
      end
    end

    def valid_file_entry?(file)
      file.is_a?(Hash) && file["filename"] && file["coverage"].is_a?(Array)
    end

    def simplecov_format?(entry)
      entry.is_a?(Hash) && entry.keys.any? { |k| k.start_with?("/") }
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

    def normalize_filename(file_path)
      return nil if file_path.nil? || file_path.empty?

      # Use current working directory as project root
      project_root = Dir.pwd

      # If the file path starts with the project root, remove that prefix
      if file_path.start_with?(project_root)
        file_path.delete_prefix(project_root).delete_prefix("/")
      else
        # If it doesn't start with project root, return as-is (assuming it's already relative)
        file_path
      end
    end
  end
end
