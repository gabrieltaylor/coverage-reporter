# frozen_string_literal: true

require "spec_helper"
require "coverage_reporter/diff_parser"

RSpec.describe CoverageReporter::DiffParser do
  subject(:parser) { described_class.new("origin/main") }

  describe "#fetch_diff" do
    context "when git diff command fails (returns nil)" do
      it "returns an empty hash" do
        allow(parser).to receive(:run_git_diff).and_return(nil)
        expect(parser.fetch_diff).to eq({})
      end
    end

    context "when git diff command raises an exception" do
      it "returns an empty hash" do
        allow(parser).to receive(:run_git_diff).and_raise("boom")
        expect(parser.fetch_diff).to eq({})
      end
    end

    context "when git diff command returns an empty string" do
      it "returns an empty hash" do
        allow(parser).to receive(:run_git_diff).and_return("")
        expect(parser.fetch_diff).to eq({})
      end
    end

    context "with a diff containing multiple files, hunks, additions and deletions" do
      let(:diff_text) do
        <<~DIFF
          diff --git a/lib/sample.rb b/lib/sample.rb
          index 0000001..0000002 100644
          --- a/lib/sample.rb
          +++ b/lib/sample.rb
          @@ -5 +5 @@
          +first addition
          @@ -10,2 +11,4 @@ some context maybe
          -line removed 1
          -line removed 2
          +add1
          +add2
          +add3
          +add4
          diff --git a/app/models/user.rb b/app/models/user.rb
          index 0000003..0000004 100644
          --- a/app/models/user.rb
          +++ b/app/models/user.rb
          @@ -1,0 +1,2 @@
          +line one
          +line two
          diff --git a/obsolete.txt b/obsolete.txt
          index 0000005..0000006 100644
          --- a/obsolete.txt
          +++ /dev/null
          @@ -1,2 +0,0 @@
          -line a
          -line b
        DIFF
      end

      it "parses and returns a hash of added line numbers per file, ignoring deleted files" do
        allow(parser).to receive(:run_git_diff).and_return(diff_text)

        result = parser.fetch_diff

        expect(result).to eq(
          "lib/sample.rb"      => [5, 11, 12, 13, 14],
          "app/models/user.rb" => [1, 2]
        )

        expect(result).not_to have_key("obsolete.txt")
      end

      it "does not include removed lines" do
        allow(parser).to receive(:run_git_diff).and_return(diff_text)
        result = parser.fetch_diff
        # Ensure no negative side line numbers (e.g., 10 from -10,2 etc.)
        expect(result.values.flatten).not_to include(10)
      end
    end
  end
end
