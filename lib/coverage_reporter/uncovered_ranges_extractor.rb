# frozen_string_literal: true

require "ripper"

module CoverageReporter
<<<<<<< Updated upstream:lib/coverage_reporter/uncovered_ranges_extractor.rb
  class UncoveredRangesExtractor
    def initialize(coverage_report)
=======
  class CoverageRangesExtractor
    def initialize(coverage_report, source_dir: nil)
>>>>>>> Stashed changes:lib/coverage_reporter/coverage_ranges_extractor.rb
      @coverage_report = coverage_report
      @source_dir = source_dir
    end

    def call
      coverage_map = {}

      return coverage_map unless coverage

      coverage.each do |filename, data|
        # Remove leading slash from file paths for consistency
        normalized_filename = filename.delete_prefix("/")
<<<<<<< Updated upstream:lib/coverage_reporter/uncovered_ranges_extractor.rb
        ranges = extract_uncovered_ranges(data["lines"])
=======
        source_path = find_source_path(normalized_filename)
        ranges = extract_coverage_ranges(data["lines"], source_path)
>>>>>>> Stashed changes:lib/coverage_reporter/coverage_ranges_extractor.rb
        coverage_map[normalized_filename] = ranges
      end

      coverage_map
    end

    private

    def coverage
      return nil unless @coverage_report.is_a?(Hash)

      @coverage_report["coverage"]
    end

<<<<<<< Updated upstream:lib/coverage_reporter/uncovered_ranges_extractor.rb
    def extract_uncovered_ranges(lines)
      return { actual_ranges: [], display_ranges: [] } unless lines.is_a?(Array)
=======
    def find_source_path(normalized_filename)
      return nil unless @source_dir

      source_path = File.join(@source_dir, normalized_filename)
      File.exist?(source_path) ? source_path : nil
    end

    def extract_coverage_ranges(lines, source_path = nil)
      return { actual_ranges: [], display_ranges: [], relevant_ranges: [] } unless lines.is_a?(Array)
>>>>>>> Stashed changes:lib/coverage_reporter/coverage_ranges_extractor.rb

      actual_uncovered_lines = []
      display_uncovered_lines = []
      i = 0

<<<<<<< Updated upstream:lib/coverage_reporter/uncovered_ranges_extractor.rb
      while i < lines.length
        if lines[i] == 0
          i = process_uncovered_range(lines, actual_uncovered_lines, display_uncovered_lines, i)
        else
          i += 1
        end
=======
      i = process_line(lines, actual_uncovered_lines, display_uncovered_lines, relevant_lines, i) while i < lines.length

      # Apply method grouping to display ranges if source file is available
      if source_path && File.exist?(source_path)
        method_boundaries = parse_method_boundaries(source_path)
        display_uncovered_lines = group_by_methods(
          actual_uncovered_lines,
          display_uncovered_lines,
          lines,
          method_boundaries
        )
      end

      build_ranges_result(actual_uncovered_lines, display_uncovered_lines, relevant_lines)
    end

    def process_line(lines, actual_lines, display_lines, relevant_lines, index)
      if lines[index] == 0
        process_uncovered_range(lines, actual_lines, display_lines, relevant_lines, index)
      elsif lines[index].is_a?(Numeric) && lines[index] > 0
        add_covered_line(relevant_lines, index)
        index + 1
      else
        index + 1
>>>>>>> Stashed changes:lib/coverage_reporter/coverage_ranges_extractor.rb
      end

      {
        actual_ranges:  convert_to_ranges(actual_uncovered_lines),
        display_ranges: convert_to_ranges(display_uncovered_lines)
      }
    end

    def process_uncovered_range(lines, actual_lines, display_lines, start_index)
      i = start_index
      # Found an uncovered line, start a range (always starts with 0)
      line_number = i + 1
      actual_lines << line_number
      display_lines << line_number
      i += 1

      # Continue through consecutive 0s and nils
      # Include nil only if it's immediately followed by an uncovered line (0)
      continue_uncovered_range(lines, actual_lines, display_lines, i)
    end

    def continue_uncovered_range(lines, actual_lines, display_lines, start_index)
      i = start_index
      while i < lines.length
        line_number = i + 1
        if lines[i] == 0
          # Actual uncovered line - add to both
          actual_lines << line_number
          display_lines << line_number
          i += 1
        elsif lines[i].nil? && should_continue_range?(lines, i)
          # Nil line that continues the range - add only to display
          display_lines << line_number
          i += 1
        else
          break
        end
      end
      i
    end

    def should_continue_range?(lines, index)
      return false unless lines[index].nil?

      # Include nil only if it's immediately followed by an uncovered line (0)
      index + 1 < lines.length && lines[index + 1] == 0
    end

    def convert_to_ranges(lines)
      return [] if lines.empty?

      ranges = []
      start_line = lines.first
      end_line = lines.first

      lines.each_cons(2) do |current, next_line|
        if next_line == current + 1
          # Consecutive lines, extend the range
          end_line = next_line
        else
          # Gap found, close current range and start new one
          ranges << [start_line, end_line]
          start_line = next_line
          end_line = next_line
        end
      end

      # Add the last range
      ranges << [start_line, end_line]
      ranges
    end

    def parse_method_boundaries(source_path)
      source_code = File.read(source_path)
      boundaries = []

      # Use Ripper.sexp to understand structure and Ripper.lex for line numbers
      sexp = Ripper.sexp(source_code)
      return boundaries unless sexp

      # Extract method boundaries by traversing the AST
      extract_method_boundaries(sexp, source_code, boundaries)
      boundaries.sort_by { |b| b[:start_line] }
    end

    def extract_method_boundaries(sexp, source_code, boundaries)
      return unless sexp.is_a?(Array)

      type = sexp[0]
      case type
      when :def
        # :def [name, params, body]
        extract_def_method(sexp, source_code, boundaries)
      when :defs
        # :defs [receiver, :".", name, params, body]
        extract_defs_method(sexp, source_code, boundaries)
      end

      # Recursively process all children
      sexp.each do |item|
        extract_method_boundaries(item, source_code, boundaries) if item.is_a?(Array)
      end
    end

    def extract_def_method(sexp, source_code, boundaries)
      # Extract line number from method name node: [:@ident, "name", [line, col]]
      method_name_node = sexp[1]
      return unless method_name_node.is_a?(Array) && method_name_node.length >= 3

      location = method_name_node[2]
      return unless location.is_a?(Array) && location.length >= 1

      def_line = location[0]
      return unless def_line.is_a?(Integer)

      # Find matching end line using source code
      end_line = find_matching_end(source_code, def_line)
      return unless end_line

      boundaries << { start_line: def_line, end_line: end_line }
    end

    def extract_defs_method(sexp, source_code, boundaries)
      # defs structure: [:defs, receiver, :".", name, params, body]
      method_name_node = sexp[3]
      return unless method_name_node.is_a?(Array) && method_name_node.length >= 3

      location = method_name_node[2]
      return unless location.is_a?(Array) && location.length >= 1

      def_line = location[0]
      return unless def_line.is_a?(Integer)

      # Find matching end line using source code
      end_line = find_matching_end(source_code, def_line)
      return unless end_line

      boundaries << { start_line: def_line, end_line: end_line }
    end

    def find_matching_end(source_code, def_line)
      lines = source_code.lines
      return nil if def_line > lines.length

      # Use a stack-based approach to find matching end
      depth = 0
      start_idx = def_line - 1

      (start_idx...lines.length).each do |idx|
        line = lines[idx]
        # Count def/end keywords (simplified - doesn't handle strings/comments perfectly)
        # But should work for most cases
        depth += line.scan(/\bdef\b/).length
        depth -= line.scan(/\bend\b/).length

        return idx + 1 if depth == 0 && idx > start_idx
      end

      lines.length # Fallback to end of file
    end

    def group_by_methods(actual_uncovered_lines, display_uncovered_lines, coverage_lines, method_boundaries)
      return display_uncovered_lines if method_boundaries.empty? || actual_uncovered_lines.empty?

      # Create a map of line number to method boundary
      line_to_method = {}
      method_boundaries.each do |boundary|
        (boundary[:start_line]..boundary[:end_line]).each do |line_num|
          line_to_method[line_num] = boundary
        end
      end

      # Group uncovered lines by method
      method_uncovered_lines = Hash.new { |h, k| h[k] = [] }
      uncovered_lines_not_in_method = []

      actual_uncovered_lines.each do |line_num|
        if line_to_method[line_num]
          method = line_to_method[line_num]
          method_uncovered_lines[method] << line_num
        else
          uncovered_lines_not_in_method << line_num
        end
      end

      # Check each method: if all executable lines in the method are uncovered, use full method range
      grouped_lines = uncovered_lines_not_in_method.dup

      method_uncovered_lines.each do |method, uncovered_lines_in_method|
        # Check if all executable lines in the method are uncovered
        # An executable line is one that has coverage data (not nil) or is explicitly 0
        method_executable_lines = find_executable_lines_in_method(
          method[:start_line],
          method[:end_line],
          coverage_lines
        )

        # Check if all executable lines are uncovered (value is 0)
        all_uncovered = method_executable_lines.all? do |line_idx|
          coverage_lines[line_idx] == 0
        end

        if all_uncovered && method_executable_lines.any?
          # All executable lines are uncovered - use entire method range
          (method[:start_line]..method[:end_line]).each do |line_num|
            grouped_lines << line_num unless grouped_lines.include?(line_num)
          end
        else
          # Some lines are covered - use original uncovered lines from display_uncovered_lines
          # that fall within this method
          display_uncovered_lines.each do |line_num|
            if line_num >= method[:start_line] && line_num <= method[:end_line]
              grouped_lines << line_num unless grouped_lines.include?(line_num)
            end
          end
        end
      end

      # Also include any display lines that weren't in methods
      display_uncovered_lines.each do |line_num|
        grouped_lines << line_num unless line_to_method[line_num]
      end

      grouped_lines.sort.uniq
    end

    def find_executable_lines_in_method(start_line, end_line, coverage_lines)
      executable_lines = []
      (start_line - 1...end_line).each do |line_idx|
        next if line_idx >= coverage_lines.length

        # A line is considered executable if it has coverage data (not nil)
        # nil typically means the line is not executable (comment, blank, etc.)
        executable_lines << line_idx if coverage_lines[line_idx] != nil
      end
      executable_lines
    end
  end
end
