# frozen_string_literal: true

require "spec_helper"

RSpec.describe CoverageReporter::InlineComment do
  let(:file) { "app/models/user.rb" }
  let(:start_line) { 5 }
  let(:end_line) { 10 }
  let(:message) { "❌ Lines 5–10 are not covered by tests." }
  let(:body) { "<!-- coverage-inline-marker -->\n#{message}\n\n_File: #{file}, line #{start_line}_\n_Commit: abc123_" }

  let(:comment) do
    described_class.new(
      file:       file,
      start_line: start_line,
      end_line:   end_line,
      message:    message,
      body:       body
    )
  end

  describe "initialization" do
    it "sets all attributes correctly" do
      expect(comment.file).to eq(file)
      expect(comment.start_line).to eq(start_line)
      expect(comment.end_line).to eq(end_line)
      expect(comment.message).to eq(message)
      expect(comment.body).to eq(body)
    end
  end

  describe "#single_line?" do
    context "when start_line equals end_line" do
      let(:end_line) { 5 }

      it "returns true" do
        expect(comment.single_line?).to be true
      end
    end

    context "when start_line differs from end_line" do
      it "returns false" do
        expect(comment.single_line?).to be false
      end
    end
  end

  describe "#range?" do
    context "when start_line equals end_line" do
      let(:end_line) { 5 }

      it "returns false" do
        expect(comment.range?).to be false
      end
    end

    context "when start_line differs from end_line" do
      it "returns true" do
        expect(comment.range?).to be true
      end
    end
  end

  describe "#to_h" do
    it "returns a hash with all attributes" do
      expected_hash = {
        file:       file,
        start_line: start_line,
        end_line:   end_line,
        message:    message,
        body:       body
      }

      expect(comment.to_h).to eq(expected_hash)
    end
  end
end
