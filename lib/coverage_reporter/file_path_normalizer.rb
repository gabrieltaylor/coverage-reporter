# frozen_string_literal: true

module CoverageReporter
  class FilePathNormalizer
    def self.call(file_path)
      new.call(file_path)
    end

    def call(file_path)
      return nil if file_path.nil? || file_path.empty?

      if file_path.start_with?(Dir.pwd)
        remove_project_root_prefix(file_path)
      elsif file_path.start_with?("/")
        extract_relative_path_from_absolute(file_path)
      else
        file_path
      end
    end

    private

    def remove_project_root_prefix(file_path)
      project_root = Dir.pwd
      file_path.delete_prefix(project_root).delete_prefix("/")
    end

    def extract_relative_path_from_absolute(file_path)
      if file_path.include?("/lib/")
        extract_path_after_pattern(file_path, "/lib/")
      elsif file_path.include?("/spec/")
        extract_path_after_pattern(file_path, "/spec/")
      else
        file_path
      end
    end

    def extract_path_after_pattern(file_path, pattern)
      index = file_path.rindex(pattern)
      file_path[(index + pattern.length)..]
    end
  end
end
