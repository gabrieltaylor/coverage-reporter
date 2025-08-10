# frozen_string_literal: true

require "spec_helper"
require "octokit"
require "coverage_reporter/comment_publisher"

RSpec.describe CoverageReporter::CommentPublisher do
  let(:repo) { "owner/repo" }
  let(:pr_number) { 42 }
  let(:chunker) { instance_double(CoverageReporter::Chunker) }
  let(:formatter) { instance_double(CoverageReporter::CommentFormatter) }
  let(:client) { instance_double(Octokit::Client) }

  subject(:publisher) { described_class.new(github: client, chunker: chunker, formatter: formatter, repo: repo) }

  describe "#publish_inline (Octokit mode)" do
    let(:uncovered_by_file) do
      {
        "app/models/user.rb" => [10, 11, 12, 20, 22, 21, 30],
        "lib/foo.rb"         => [5, 5]
      }
    end

    let(:existing_inline_comment) { double("Comment", id: 1, body: "<!-- coverage-inline-marker -->\nOld inline body") }
    let(:other_comment) { double("Comment", id: 2, body: "Some unrelated comment") }

    it "deletes prior inline comments (marked) then chunks, formats, and posts new inline comments as issue comments" do
      # Delete old inline comments
      expect(client).to receive(:issue_comments).with(repo, pr_number).and_return([existing_inline_comment, other_comment])
      expect(client).to receive(:delete_comment).with(repo, existing_inline_comment.id)

      # Chunking expectations
      expect(chunker).to receive(:chunks).with([10, 11, 12, 20, 22, 21, 30])
        .and_return([[10, 11, 12], [20, 21, 22], [30]]).ordered
      expect(chunker).to receive(:chunks).with([5, 5])
        .and_return([[5], [5]]).ordered

      # Formatting + add_comment expectations
      user_chunks_messages = {
        [10, 11, 12] => "user msg A",
        [20, 21, 22] => "user msg B",
        [30]         => "user msg C"
      }

      user_chunks_messages.each do |chunk, message|
        expect(formatter).to receive(:inline_chunk_message)
          .with(file: "app/models/user.rb", chunk: chunk)
          .and_return(message).ordered
        expect(client).to receive(:add_comment) do |r, pr, body|
          expect(r).to eq(repo)
            .and be_truthy
          expect(pr).to eq(pr_number)
          expect(body).to include("<!-- coverage-inline-marker -->")
          expect(body).to include(message)
          expect(body).to include("_File: app/models/user.rb, line #{chunk.first}_")
        end.ordered
      end

      # First duplicate line chunk
      expect(formatter).to receive(:inline_chunk_message)
        .with(file: "lib/foo.rb", chunk: [5])
        .and_return("foo msg 1").ordered
      expect(client).to receive(:add_comment) do |_, _, body|
        expect(body).to include("foo msg 1")
        expect(body).to include("_File: lib/foo.rb, line 5_")
      end.ordered

      # Second duplicate line chunk (distinct call)
      expect(formatter).to receive(:inline_chunk_message)
        .with(file: "lib/foo.rb", chunk: [5])
        .and_return("foo msg 2").ordered
      expect(client).to receive(:add_comment) do |_, _, body|
        expect(body).to include("foo msg 2")
      end.ordered

      publisher.publish_inline(pr_number: pr_number, uncovered_by_file: uncovered_by_file)
    end

    it "only deletes existing inline comments when there are no uncovered lines" do
      expect(client).to receive(:issue_comments).with(repo, pr_number).and_return([existing_inline_comment])
      expect(client).to receive(:delete_comment).with(repo, existing_inline_comment.id)
      publisher.publish_inline(pr_number: pr_number, uncovered_by_file: {})
    end
  end

  describe "#publish_global (Octokit mode)" do
    let(:diff_coverage) { 91.23 }
    let(:body) { "summary body" }

    before do
      expect(formatter).to receive(:global_summary)
        .with(diff_coverage: diff_coverage)
        .and_return(body)
    end

    context "when a global comment already exists" do
      let(:existing_global_comment) { double("Comment", id: 55, body: "<!-- coverage-comment-marker -->\nOld summary") }

      it "updates the existing global summary comment" do
        expect(client).to receive(:issue_comments).with(repo, pr_number).and_return([existing_global_comment])
        expect(client).to receive(:update_comment) do |r, id, new_body|
          expect(r).to eq(repo)
          expect(id).to eq(existing_global_comment.id)
          expect(new_body).to include("<!-- coverage-comment-marker -->")
          expect(new_body).to include(body)
        end
        publisher.publish_global(pr_number: pr_number, diff_coverage: diff_coverage)
      end
    end

    context "when there is no existing global comment" do
      it "creates a new global summary comment" do
        expect(client).to receive(:issue_comments).with(repo, pr_number).and_return([])
        expect(client).to receive(:add_comment) do |r, pr, new_body|
          expect(r).to eq(repo)
          expect(pr).          to eq(pr_number)
          expect(new_body).to include("<!-- coverage-comment-marker -->")
          expect(new_body).to include(body)
        end
        publisher.publish_global(pr_number: pr_number, diff_coverage: diff_coverage)
      end
    end
  end
end
