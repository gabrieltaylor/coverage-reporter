# frozen_string_literal: true

module CoverageReporter
  class ModifiedRangesExtractor
    HUNK_HEADER = /^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@/

    def initialize(diff_text)
      @diff_text = diff_text
    end

    def call
      return {} unless @diff_text

      parse_diff(@diff_text)
    rescue StandardError
      {}
    end

    private

    def parse_diff(text)
      changed = Hash.new { |h, k| h[k] = [] }
      current_file = nil
      current_new_line = nil

      text.each_line do |raw_line|
        line = raw_line.chomp

        if file_header_line?(line)
          current_file = parse_new_file_path(line)
          next
        end

        if (m = hunk_header_match(line))
          current_new_line = m[1].to_i
          next
        end

        next unless current_file && current_new_line

        current_new_line = process_content_line(line, changed, current_file, current_new_line)
      end

      # Convert arrays of line numbers to ranges
      changed.transform_values { |arr| consolidate_to_ranges(arr.uniq.sort) }
    end

    def file_header_line?(line)
      line.start_with?("+++ ")
    end

    def hunk_header_match(line)
      HUNK_HEADER.match(line)
    end

    def process_content_line(line, changed, current_file, current_new_line)
      case line[0]
      when "+"
        handle_added_line(line, changed, current_file, current_new_line)
      when "-"
        current_new_line
      when " "
        current_new_line + 1
      end
    end

    def handle_added_line(line, changed, current_file, current_new_line)
      return current_new_line if line.start_with?("+++ ")

      changed[current_file] << current_new_line
      current_new_line + 1
    end

    def parse_new_file_path(line)
      return nil if line.end_with?(File::NULL)

      if (m = line.match(%r{\A\+\+\+\s[wb]/(.+)\z}))
        m[1]
      end
    end

    def consolidate_to_ranges(line_numbers)
      return [] if line_numbers.empty?

      ranges = []
      start = line_numbers.first
      last = line_numbers.first

      line_numbers.each_cons(2) do |current, next_line|
        if next_line == current + 1
          # Consecutive line, extend current range
          last = next_line
        else
          # Gap found, close current range and start new one
          ranges << [start, last]
          start = next_line
          last = next_line
        end
      end

      # Add the final range
      ranges << [start, last]
      ranges
    end
  end
end
