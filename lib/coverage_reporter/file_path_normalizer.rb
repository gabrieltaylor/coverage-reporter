# frozen_string_literal: true

module CoverageReporter
  class FilePathNormalizer
    NON_SOURCE_DIRS = %w[
      tmp
      temp
      cache
      log
      logs
      vendor
      node_modules
      bower_components
      public
      assets
      images
      css
      js
      fonts
      config
      db
      migrations
      bin
      exe
      scripts
      tools
      build
      dist
      target
      out
      coverage
      doc
      docs
      documentation
      .git
      .github
      .vscode
      .idea
    ].freeze

    def self.call(file_path)
      new.call(file_path)
    end

    def call(file_path)
      return nil if file_path.nil? || file_path.empty?

      if file_path.start_with?(Dir.pwd)
        file_path.delete_prefix(Dir.pwd).delete_prefix("/")
      elsif file_path.start_with?("/")
        extract_from_absolute_path(file_path)
      else
        file_path
      end
    end

    private

    def extract_from_absolute_path(file_path)
      source_dir = find_source_directory_in_path(file_path)
      if source_dir
        pattern_index = file_path.rindex("/#{source_dir}/")
        file_path[(pattern_index + 1)..]
      else
        file_path
      end
    end

    def find_source_directory_in_path(file_path)
      # Get directories that contain Ruby files in this project
      source_dirs = Dir.glob("#{Dir.pwd}/*")
        .select { |path| File.directory?(path) && contains_ruby_files?(path) }
        .map { |path| File.basename(path) }

      # Find the first source directory that appears in the file path
      source_dirs.find { |dir| file_path.include?("/#{dir}/") }
    end

    def contains_ruby_files?(dir_path)
      # Skip common non-source directories
      dir_name = File.basename(dir_path).downcase

      return false if NON_SOURCE_DIRS.include?(dir_name)

      # Look for Ruby files in this directory
      Dir.glob("#{dir_path}/**/*.rb", File::FNM_DOTMATCH).any?
    end
  end
end
