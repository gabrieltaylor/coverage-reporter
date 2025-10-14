# frozen_string_literal: true

require "simplecov_json_formatter"

module CoverageReporter
  module SimpleCov
    module Patches
      module ResultHashFormatterPatch
        def self.included(base)
          base.class_eval do
            private

            def format_files
              @result.files.each do |source_file|
                # Use project_filename instead of filename to get the relative path
                formatted_result[:coverage][source_file.project_filename] = format_source_file(source_file)
              end
            end
          end
        end
      end
    end
  end
end

SimpleCovJSONFormatter::ResultHashFormatter.include(CoverageReporter::SimpleCov::Patches::ResultHashFormatterPatch)
