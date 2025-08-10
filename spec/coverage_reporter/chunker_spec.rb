# frozen_string_literal: true

require "spec_helper"
require "coverage_reporter/chunker"

RSpec.describe CoverageReporter::Chunker do
  subject(:chunker) { described_class.new }

  describe "#chunks" do
    context "when lines is nil" do
      it "returns an empty array" do
        expect(chunker.chunks(nil)).to eq([])
      end
    end

    context "when lines is empty" do
      it "returns an empty array" do
        expect(chunker.chunks([])).to eq([])
      end
    end

    context "with a single line" do
      it "returns an array containing one chunk" do
        expect(chunker.chunks([7])).to eq([[7]])
      end
    end

    context "with already sorted contiguous lines" do
      it "returns a single chunk" do
        expect(chunker.chunks([10, 11, 12])).to eq([[10, 11, 12]])
      end
    end

    context "with non-contiguous lines" do
      it "splits them into separate chunks" do
        expect(chunker.chunks([10, 11, 15, 20, 21, 23]))
          .to eq([[10, 11], [15], [20, 21], [23]])
      end
    end

    context "when input is unsorted" do
      it "sorts first, then chunks contiguous sequences" do
        # Sorted form: [1, 2, 4, 5]
        expect(chunker.chunks([5, 1, 2, 4])).to eq([[1, 2], [4, 5]])
      end
    end

    context "when there are duplicates" do
      it "treats duplicates as breaks unless followed by the next increment" do
        # Sorted: [3, 3, 4] -> chunks: [3], [3,4]
        expect(chunker.chunks([3, 4, 3])).to eq([[3], [3, 4]])
      end
    end

    context "with a larger mixed example" do
      it "handles multiple groups correctly" do
        input  = [30, 10, 11, 12, 25, 27, 28, 40, 41, 50]
        output = [[10, 11, 12], [25], [27, 28], [30], [40, 41], [50]]
        expect(chunker.chunks(input)).to eq(output)
      end
    end

    context "when preserving input immutability" do
      it "does not modify the original array" do
        original = [3, 1, 2]
        dup = original.dup
        chunker.chunks(original)
        expect(original).to eq(dup)
      end
    end

    context "when coercing non-array input" do
      it "Array() wraps non-array input (e.g., a single integer) into a single chunk" do
        expect(chunker.chunks(42)).to eq([[42]])
      end
    end
  end
end
