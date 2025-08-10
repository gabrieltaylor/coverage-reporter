# frozen_string_literal: true

require "spec_helper"
require "coverage_reporter/comment_publisher"

RSpec.describe CoverageReporter::CommentPublisher do
  subject(:publisher) { described_class.new(github: github, chunker: chunker, formatter: formatter) }

  let(:pr_number) { 42 }
  let(:github) { instance_double(Github) }
  let(:chunker) { instance_double(CoverageReporter::Chunker) }
  let(:formatter) { instance_double(CoverageReporter::CommentFormatter) }

  describe "#publish_inline" do
    context "with multiple files and unsorted, duplicate lines" do
      let(:uncovered_by_file) do
        {
          "app/models/user.rb" => [10, 11, 12, 20, 22, 21, 30],
          "lib/foo.rb"         => [5, 5]
        }
      end

      it "deletes old comments, chunks lines, formats each chunk and posts inline comments" do
        # Expect deletion first
        expect(github).to receive(:delete_old_inline_comments).with(pr_number).ordered

        # Stub chunking behaviour (publisher passes the raw arrays to chunker)
        expect(chunker).to receive(:chunks)
          .with([10, 11, 12, 20, 22, 21, 30])
          .and_return([[10, 11, 12], [20, 21, 22], [30]]).ordered

        expect(chunker).to receive(:chunks)
          .with([5, 5])
          .and_return([[5], [5]]).ordered

        # Stub/expect formatting + posting for each chunk in order
        user_chunks_messages = {
          [10, 11, 12] => "user msg A",
          [20, 21, 22] => "user msg B",
          [30]         => "user msg C"
        }

        user_chunks_messages.each do |chunk, message|
          expect(formatter).to receive(:inline_chunk_message)
            .with(file: "app/models/user.rb", chunk: chunk)
            .and_return(message).ordered
          expect(github).to receive(:comment_on_line)
            .with(pr_number, "app/models/user.rb", chunk.first, message).ordered
        end

        # First duplicate line chunk [5]
        expect(formatter).to receive(:inline_chunk_message)
          .with(file: "lib/foo.rb", chunk: [5])
          .and_return("foo msg 1").ordered
        expect(github).to receive(:comment_on_line)
          .with(pr_number, "lib/foo.rb", 5, "foo msg 1").ordered

        # Second duplicate line chunk [5]
        expect(formatter).to receive(:inline_chunk_message)
          .with(file: "lib/foo.rb", chunk: [5])
          .and_return("foo msg 2").ordered
        expect(github).to receive(:comment_on_line)
          .with(pr_number, "lib/foo.rb", 5, "foo msg 2").ordered

        publisher.publish_inline(pr_number: pr_number, uncovered_by_file: uncovered_by_file)
      end
    end

    context "when there are no uncovered lines" do
      it "only deletes existing inline comments" do
        expect(github).to receive(:delete_old_inline_comments).with(pr_number)
        publisher.publish_inline(pr_number: pr_number, uncovered_by_file: {})
      end
    end
  end

  describe "#publish_global" do
    it "formats the summary and posts (or updates) the global comment" do
      diff_coverage = 91.23
      body = "summary body"
      expect(formatter).to receive(:global_summary)
        .with(diff_coverage: diff_coverage)
        .and_return(body)
      expect(github).to receive(:post_or_update_global_comment)
        .with(pr_number, body)
      publisher.publish_global(pr_number: pr_number, diff_coverage: diff_coverage)
    end
  end
end
