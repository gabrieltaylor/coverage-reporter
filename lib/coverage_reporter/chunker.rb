# frozen_string_literal: true

module CoverageReporter
  class Chunker
    # Given [10,11,12, 15] => [[10,11,12],[15]]
    def chunks(lines)
      Array(lines).sort.chunk_while { |i, j| j == i + 1 }.to_a
    end
  end
end
