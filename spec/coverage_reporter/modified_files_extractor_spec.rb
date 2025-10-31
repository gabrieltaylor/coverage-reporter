# frozen_string_literal: true

require "spec_helper"

RSpec.describe CoverageReporter::ModifiedFilesExtractor do
  describe "#call" do
    context "when diff text is nil" do
      subject(:extractor) { described_class.new(nil) }

      it "returns an empty array" do
        expect(extractor.call).to eq([])
      end
    end

    context "when diff text is empty" do
      subject(:extractor) { described_class.new("") }

      it "returns an empty array" do
        expect(extractor.call).to eq([])
      end
    end

    context "when parsing raises an exception" do
      subject(:extractor) { described_class.new("invalid diff") }

      it "returns an empty array and prints warning" do
        allow(extractor).to receive(:parse_diff).and_raise("boom")
        expect { extractor.call }.to output(/Warning: Could not parse diff text: boom/).to_stdout
        expect(extractor.call).to eq([])
      end
    end

    context "with a diff containing multiple files" do
      subject(:extractor) { described_class.new(diff_text) }

      let(:diff_text) do
        <<~DIFF
          diff --git a/lib/sample.rb b/lib/sample.rb
          index 0000001..0000002 100644
          --- a/lib/sample.rb
          +++ b/lib/sample.rb
          @@ -5 +5 @@
          +first addition
          diff --git a/app/models/user.rb b/app/models/user.rb
          index 0000003..0000004 100644
          --- a/app/models/user.rb
          +++ b/app/models/user.rb
          @@ -1,0 +1,2 @@
          +line one
          +line two
          diff --git a/README.md b/README.md
          index 0000005..0000006 100644
          --- a/README.md
          +++ b/README.md
          @@ -1,2 +1,3 @@
          # Project Title
          +New line added
          diff --git a/obsolete.txt b/obsolete.txt
          index 0000007..0000008 100644
          --- a/obsolete.txt
          +++ /dev/null
          @@ -1,2 +0,0 @@
          -line a
          -line b
        DIFF
      end

      it "extracts all modified file paths" do
        result = extractor.call

        expect(result).to eq([
          "README.md",
          "app/models/user.rb",
          "lib/sample.rb"
        ])
      end

      it "excludes deleted files (dev/null)" do
        result = extractor.call

        expect(result).not_to include("obsolete.txt")
      end

      it "returns files in sorted order" do
        result = extractor.call

        expect(result).to eq(result.sort)
      end
    end

    context "with a diff containing only one file" do
      subject(:extractor) { described_class.new(diff_text) }

      let(:diff_text) do
        <<~DIFF
          diff --git a/single_file.rb b/single_file.rb
          index 0000001..0000002 100644
          --- a/single_file.rb
          +++ b/single_file.rb
          @@ -1,0 +1,1 @@
          +puts "Hello, World!"
        DIFF
      end

      it "returns the single file path" do
        result = extractor.call

        expect(result).to eq(["single_file.rb"])
      end
    end

    context "with a diff containing no file headers" do
      subject(:extractor) { described_class.new(diff_text) }

      let(:diff_text) do
        <<~DIFF
          This is not a valid diff format
          Just some random text
          Without any +++ headers
        DIFF
      end

      it "returns an empty array" do
        result = extractor.call

        expect(result).to eq([])
      end
    end

    context "with a diff containing binary files" do
      subject(:extractor) { described_class.new(diff_text) }

      let(:diff_text) do
        <<~DIFF
          diff --git a/image.png b/image.png
          index 0000001..0000002 100644
          --- a/image.png
          +++ b/image.png
          Binary files differ
          diff --git a/lib/sample.rb b/lib/sample.rb
          index 0000003..0000004 100644
          --- a/lib/sample.rb
          +++ b/lib/sample.rb
          @@ -1,0 +1,1 @@
          +puts "Hello"
        DIFF
      end

      it "includes binary files in the result" do
        result = extractor.call

        expect(result).to eq(["image.png", "lib/sample.rb"])
      end
    end

    context "with a diff containing files with different path formats" do
      subject(:extractor) { described_class.new(diff_text) }

      let(:diff_text) do
        <<~DIFF
          diff --git a/lib/sample.rb b/lib/sample.rb
          index 0000001..0000002 100644
          --- a/lib/sample.rb
          +++ b/lib/sample.rb
          @@ -1,0 +1,1 @@
          +puts "Hello"
          diff --git a/app/models/user.rb b/app/models/user.rb
          index 0000003..0000004 100644
          --- a/app/models/user.rb
          +++ b/app/models/user.rb
          @@ -1,0 +1,1 @@
          +puts "World"
          diff --git a/config/database.yml b/config/database.yml
          index 0000005..0000006 100644
          --- a/config/database.yml
          +++ b/config/database.yml
          @@ -1,0 +1,1 @@
          +database: test
        DIFF
      end

      it "extracts all file paths correctly" do
        result = extractor.call

        expect(result).to eq([
          "app/models/user.rb",
          "config/database.yml",
          "lib/sample.rb"
        ])
      end
    end

    context "with a diff containing duplicate file entries" do
      subject(:extractor) { described_class.new(diff_text) }

      let(:diff_text) do
        <<~DIFF
          diff --git a/lib/sample.rb b/lib/sample.rb
          index 0000001..0000002 100644
          --- a/lib/sample.rb
          +++ b/lib/sample.rb
          @@ -1,0 +1,1 @@
          +puts "Hello"
          diff --git a/lib/sample.rb b/lib/sample.rb
          index 0000003..0000004 100644
          --- a/lib/sample.rb
          +++ b/lib/sample.rb
          @@ -5,0 +6,1 @@
          +puts "World"
        DIFF
      end

      it "returns unique file paths only" do
        result = extractor.call

        expect(result).to eq(["lib/sample.rb"])
      end
    end

    context "with a diff containing files with special characters" do
      subject(:extractor) { described_class.new(diff_text) }

      let(:diff_text) do
        <<~DIFF
          diff --git a/lib/sample-file.rb b/lib/sample-file.rb
          index 0000001..0000002 100644
          --- a/lib/sample-file.rb
          +++ b/lib/sample-file.rb
          @@ -1,0 +1,1 @@
          +puts "Hello"
          diff --git a/app/models/user_model.rb b/app/models/user_model.rb
          index 0000003..0000004 100644
          --- a/app/models/user_model.rb
          +++ b/app/models/user_model.rb
          @@ -1,0 +1,1 @@
          +puts "World"
        DIFF
      end

      it "handles files with special characters in names" do
        result = extractor.call

        expect(result).to eq([
          "app/models/user_model.rb",
          "lib/sample-file.rb"
        ])
      end
    end
  end

  describe "#file_header_line?" do
    subject(:extractor) { described_class.new("") }

    it "returns true for lines starting with '+++ '" do
      expect(extractor.send(:file_header_line?, "+++ b/lib/sample.rb")).to be true
    end

    it "returns false for lines not starting with '+++ '" do
      expect(extractor.send(:file_header_line?, "--- a/lib/sample.rb")).to be false
      expect(extractor.send(:file_header_line?, "diff --git")).to be false
      expect(extractor.send(:file_header_line?, "index 0000001..0000002")).to be false
      expect(extractor.send(:file_header_line?, "@@ -1,0 +1,1 @@")).to be false
      expect(extractor.send(:file_header_line?, "+puts \"Hello\"")).to be false
    end
  end

  describe "#parse_file_path" do
    subject(:extractor) { described_class.new("") }

    it "extracts file path from standard +++ header" do
      expect(extractor.send(:parse_file_path, "+++ b/lib/sample.rb")).to eq("lib/sample.rb")
    end

    it "extracts file path from +++ header with 'w' prefix" do
      expect(extractor.send(:parse_file_path, "+++ w/app/models/user.rb")).to eq("app/models/user.rb")
    end

    it "returns nil for deleted files (dev/null)" do
      expect(extractor.send(:parse_file_path, "+++ /dev/null")).to be_nil
    end

    it "returns nil for lines that don't match the pattern" do
      expect(extractor.send(:parse_file_path, "--- a/lib/sample.rb")).to be_nil
      expect(extractor.send(:parse_file_path, "diff --git")).to be_nil
      expect(extractor.send(:parse_file_path, "index 0000001..0000002")).to be_nil
    end

    it "handles files with complex paths" do
      expect(extractor.send(:parse_file_path, "+++ b/app/models/user_model.rb")).to eq("app/models/user_model.rb")
      expect(extractor.send(:parse_file_path, "+++ b/config/database.yml")).to eq("config/database.yml")
      expect(extractor.send(:parse_file_path, "+++ b/lib/coverage_reporter/modified_files_extractor.rb")).to eq("lib/coverage_reporter/modified_files_extractor.rb")
    end
  end

  context "with real diff.txt file" do
    subject(:extractor) { described_class.new(diff_text) }

    let(:diff_text) { File.read(File.join(__dir__, "../fixtures/diff.txt")) }

    it "parses the real diff file and returns modified files" do
      result = extractor.call

      expected_files = [
        ".buildkite/pipeline.yml",
        ".buildkite/script/collate",
        ".buildkite/script/report",
        ".buildkite/script/test",
        "README.md",
        "bin/setup",
        "coverage-reporter.gemspec",
        "lib/coverage_reporter.rb",
        "lib/coverage_reporter/coverage_analyzer.rb",
        "lib/coverage_reporter/global_comment.rb",
        "lib/coverage_reporter/options.rb",
        "lib/coverage_reporter/runner.rb",
        "scripts/README.md",
        "scripts/capture.sh",
        "scripts/capture_fixtures.rb",
        "scripts/capture_raw_requests.rb",
        "scripts/run_with_logging.rb",
        "spec/coverage_reporter/cli_spec.rb",
        "spec/coverage_reporter/coverage_analyzer_spec.rb",
        "spec/coverage_reporter/coverage_report_loader_spec.rb",
        "spec/coverage_reporter/global_comment_spec.rb",
        "spec/coverage_reporter/integration_spec.rb",
        "spec/coverage_reporter/options_spec.rb",
        "spec/coverage_reporter/runner_spec.rb",
        "spec/fixtures/comment_requests.json"
      ]

      expect(result).to eq(expected_files)
    end
  end
end
