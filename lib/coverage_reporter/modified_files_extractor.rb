# frozen_string_literal: true

require "set"

module CoverageReporter
  # Extracts a list of modified files from diff text
  class ModifiedFilesExtractor
    def initialize(diff_text)
      @diff_text = diff_text
    end

    def call
      return [] unless @diff_text

      parse_diff(@diff_text)
    rescue StandardError => e
      puts "Warning: Could not parse diff text: #{e.message}"
      []
    end

    private

    def parse_diff(text)
      modified_files = Set.new

      text.each_line do |line|
        if file_header_line?(line)
          file_path = parse_file_path(line)
          modified_files.add(file_path) if file_path
        end
      end

      modified_files.to_a.sort
    end

    def file_header_line?(line)
      line.start_with?("+++ ")
    end

    def parse_file_path(line)
      return nil if line.end_with?(File::NULL)

      line = line.chomp
      if (m = line.match(%r{\A\+\+\+\s[wb]/(.+)\z}))
        m[1]
      end
    end
  end
end
