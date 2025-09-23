# frozen_string_literal: true

require "spec_helper"

RSpec.describe CoverageReporter::ModifiedRangesExtractor do
  describe "#call" do
    context "when diff text is nil" do
      subject(:extractor) { described_class.new(nil) }

      it "returns an empty hash" do
        expect(extractor.call).to eq({})
      end
    end

    context "when diff text is empty" do
      subject(:extractor) { described_class.new("") }

      it "returns an empty hash" do
        expect(extractor.call).to eq({})
      end
    end

    context "when parsing raises an exception" do
      subject(:extractor) { described_class.new("invalid diff") }

      it "returns an empty hash" do
        allow(extractor).to receive(:parse_diff).and_raise("boom")
        expect(extractor.call).to eq({})
      end
    end

    context "with a diff containing multiple files, hunks, additions and deletions" do
      subject(:extractor) { described_class.new(diff_text) }

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

      it "parses and returns a hash of line ranges per file, ignoring deleted files" do
        result = extractor.call

        expect(result).to eq(
          "lib/sample.rb"      => [[5, 5], [11, 14]],
          "app/models/user.rb" => [[1, 2]]
        )

        expect(result).not_to have_key("obsolete.txt")
      end

      it "does not include removed lines" do
        result = extractor.call
        # Ensure no negative side line numbers (e.g., 10 from -10,2 etc.)
        expect(result.values.flatten).not_to include(10)
      end
    end

    context "with consecutive line additions" do
      subject(:extractor) { described_class.new(diff_text) }

      let(:diff_text) do
        <<~DIFF
          diff --git a/test.rb b/test.rb
          index 0000001..0000002 100644
          --- a/test.rb
          +++ b/test.rb
          @@ -1,0 +1,5 @@
          +line 1
          +line 2
          +line 3
          +line 4
          +line 5
        DIFF
      end

      it "consolidates consecutive lines into a single range" do
        result = extractor.call

        expect(result).to eq(
          "test.rb" => [[1, 5]]
        )
      end
    end

    context "with non-consecutive line additions" do
      subject(:extractor) { described_class.new(diff_text) }

      let(:diff_text) do
        <<~DIFF
          diff --git a/test.rb b/test.rb
          index 0000001..0000002 100644
          --- a/test.rb
          +++ b/test.rb
          @@ -1,0 +1,1 @@
          +line 1
          @@ -5,0 +6,1 @@
          +line 6
          @@ -10,0 +11,1 @@
          +line 11
        DIFF
      end

      it "creates separate ranges for non-consecutive lines" do
        result = extractor.call

        expect(result).to eq(
          "test.rb" => [[1, 1], [6, 6], [11, 11]]
        )
      end
    end

    context "with mixed consecutive and non-consecutive lines" do
      subject(:extractor) { described_class.new(diff_text) }

      let(:diff_text) do
        <<~DIFF
          diff --git a/test.rb b/test.rb
          index 0000001..0000002 100644
          --- a/test.rb
          +++ b/test.rb
          @@ -1,0 +1,3 @@
          +line 1
          +line 2
          +line 3
          @@ -10,0 +11,1 @@
          +line 11
          @@ -15,0 +16,2 @@
          +line 16
          +line 17
          @@ -25,0 +27,1 @@
          +line 27
        DIFF
      end

      it "creates appropriate ranges for mixed patterns" do
        result = extractor.call

        expect(result).to eq(
          "test.rb" => [[1, 3], [11, 11], [16, 17], [27, 27]]
        )
      end
    end
  end

  describe "#consolidate_to_ranges" do
    subject(:extractor) { described_class.new("") }

    it "returns empty array for empty input" do
      expect(extractor.send(:consolidate_to_ranges, [])).to eq([])
    end

    it "returns single range for single line" do
      expect(extractor.send(:consolidate_to_ranges, [5])).to eq([[5, 5]])
    end

    it "consolidates consecutive lines" do
      expect(extractor.send(:consolidate_to_ranges, [1, 2, 3, 4, 5])).to eq([[1, 5]])
    end

    it "creates separate ranges for non-consecutive lines" do
      expect(extractor.send(:consolidate_to_ranges, [1, 3, 5, 7, 9])).to eq([[1, 1], [3, 3], [5, 5], [7, 7], [9, 9]])
    end

    it "handles mixed consecutive and non-consecutive lines" do
      expect(extractor.send(:consolidate_to_ranges, [1, 2, 3, 5, 6, 8, 10, 11, 12, 15])).to eq(
        [[1, 3], [5, 6], [8, 8], [10, 12], [15, 15]]
      )
    end
  end
end
