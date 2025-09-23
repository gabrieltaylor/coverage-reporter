# frozen_string_literal: true

require "json"

module CoverageReporter
  class CoverageReportLoader
    def initialize(coverage_file_path)
      @coverage_file_path = coverage_file_path
    end

    def call
      content = File.read(@coverage_file_path)
      JSON.parse(content)
    end

    private

    attr_reader :coverage_file_path
  end
end
