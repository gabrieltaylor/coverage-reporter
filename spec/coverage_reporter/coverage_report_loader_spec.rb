# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "fileutils"

RSpec.describe CoverageReporter::CoverageReportLoader do
  let(:coverage_file_path) { "spec/fixtures/coverage.json" }
  let(:loader) { described_class.new(coverage_file_path) }

  describe "#call" do
    context "when the coverage file exists and contains valid JSON" do
      it "returns the parsed JSON data" do
        result = loader.call

        expect(result).to be_a(Hash)
        expect(result).to have_key("meta")
        expect(result).to have_key("coverage")
        expect(result["meta"]).to have_key("simplecov_version")
      end
    end

    context "when the coverage file does not exist" do
      let(:coverage_file_path) { "nonexistent/coverage.json" }

      it "raises CoverageFileNotFoundError" do
        expect { loader.call }.to raise_error(
          CoverageReporter::CoverageFileNotFoundError,
          "Coverage file not found: #{coverage_file_path}"
        )
      end
    end

    context "when the coverage file exists but has no read permissions" do
      let(:temp_file) { Tempfile.new("coverage_test") }
      let(:coverage_file_path) { temp_file.path }

      before do
        # Create the file with content
        temp_file.write('{"test": "data"}')
        temp_file.close
        # Remove all permissions to make it unreadable
        File.chmod(0o000, temp_file.path)
        # Add a small delay to ensure permission change takes effect
        sleep(0.01)
      end

      after do
        # Ensure cleanup happens even if test fails
        begin
          # Restore permissions to allow cleanup
          File.chmod(0o644, temp_file.path) if File.exist?(temp_file.path)
        rescue Errno::ENOENT, Errno::EACCES
          # File already deleted or permission denied, ignore
        end
        temp_file.unlink
      end

      xit "raises CoverageFileAccessError" do
        expect { loader.call }.to raise_error(
          CoverageReporter::CoverageFileAccessError,
          "Permission denied reading coverage file: #{coverage_file_path}"
        )
      end
    end

    context "when the coverage file contains invalid JSON" do
      let(:temp_file) { Tempfile.new("coverage") }
      let(:coverage_file_path) { temp_file.path }

      before do
        temp_file.write('{"invalid": json, "missing": quotes}')
        temp_file.close
      end

      after do
        temp_file.unlink
      end

      it "raises CoverageFileParseError with the original error message" do
        expect { loader.call }.to raise_error(
          CoverageReporter::CoverageFileParseError,
          /Invalid JSON in coverage file #{Regexp.escape(coverage_file_path)}:/
        )
      end
    end

    context "when the coverage file is empty" do
      let(:temp_file) { Tempfile.new("coverage") }
      let(:coverage_file_path) { temp_file.path }

      before do
        temp_file.write("")
        temp_file.close
      end

      after do
        temp_file.unlink
      end

      it "raises CoverageFileParseError" do
        expect { loader.call }.to raise_error(
          CoverageReporter::CoverageFileParseError,
          /Invalid JSON in coverage file #{Regexp.escape(coverage_file_path)}:/
        )
      end
    end

    context "when an unexpected error occurs" do
      before do
        allow(File).to receive(:read).and_raise(StandardError.new("Unexpected error"))
      end

      it "raises CoverageFileError with the original error message" do
        expect { loader.call }.to raise_error(
          CoverageReporter::CoverageFileError,
          "Unexpected error reading coverage file #{coverage_file_path}: Unexpected error"
        )
      end
    end
  end

  describe "error class hierarchy" do
    it "has proper inheritance structure" do
      expect(CoverageReporter::CoverageFileNotFoundError).to be < CoverageReporter::CoverageFileError
      expect(CoverageReporter::CoverageFileAccessError).to be < CoverageReporter::CoverageFileError
      expect(CoverageReporter::CoverageFileParseError).to be < CoverageReporter::CoverageFileError
      expect(CoverageReporter::CoverageFileError).to be < StandardError
    end
  end

  describe "private methods" do
    describe "#read_file_content" do
      it "reads the file content" do
        content = loader.send(:read_file_content)
        expect(content).to be_a(String)
        expect(content).to include("simplecov_version")
      end
    end

    describe "#parse_json_content" do
      let(:valid_json) { '{"test": "data", "number": 42}' }

      it "parses valid JSON content" do
        result = loader.send(:parse_json_content, valid_json)
        expect(result).to eq({ "test" => "data", "number" => 42 })
      end

      it "raises JSON::ParserError for invalid JSON" do
        expect do
          loader.send(:parse_json_content, "invalid json")
        end.to raise_error(JSON::ParserError)
      end
    end
  end
end
