# frozen_string_literal: true

require "spec_helper"

RSpec.describe CoverageReporter::InlineComment do
  let(:path) { "app/models/user.rb" }
  let(:start_line) { 5 }
  let(:line) { 10 }
  let(:message) { "❌ Lines 5–10 are not covered by tests." }
  let(:body) { "<!-- coverage-inline-marker -->\n#{message}\n\n_File: #{path}, line #{start_line}_\n_Commit: abc123_" }

  let(:comment) do
    described_class.new(
      path:       path,
      start_line: start_line,
      line:       line,
      body:       body
    )
  end

  describe "initialization" do
    it "sets all attributes correctly" do
      expect(comment.path).to eq(path)
      expect(comment.start_line).to eq(start_line)
      expect(comment.line).to eq(line)
      expect(comment.body).to eq(body)
    end
  end

  describe "#single_line?" do
    context "when start_line equals line" do
      let(:line) { 5 }

      it "returns true" do
        expect(comment.single_line?).to be true
      end
    end

    context "when start_line differs from line" do
      it "returns false" do
        expect(comment.single_line?).to be false
      end
    end
  end

  describe "#range?" do
    context "when start_line equals line" do
      let(:line) { 5 }

      it "returns false" do
        expect(comment.range?).to be false
      end
    end

    context "when start_line differs from line" do
      it "returns true" do
        expect(comment.range?).to be true
      end
    end
  end
end
