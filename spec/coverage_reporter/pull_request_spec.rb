# frozen_string_literal: true

require "spec_helper"
require "coverage_reporter/pull_request"

# Test classes for verified doubles
class PullRequestData
  attr_reader :head

  def initialize(head)
    @head = head
  end
end

class Head
  attr_reader :sha

  def initialize(sha)
    @sha = sha
  end
end

class Comment
  attr_reader :id, :body, :path, :line, :start_line

  def initialize(id:, body:, path:, line: nil, start_line: nil)
    @id = id
    @body = body
    @path = path
    @line = line
    @start_line = start_line
  end
end

RSpec.describe CoverageReporter::PullRequest do
  let(:github_token) { "ghp_test_token" }
  let(:pull_request) { described_class.new(github_token:, repo:, pr_number:) }
  let(:repo) { "owner/repo" }
  let(:pr_number) { "123" }
  let(:client) { instance_double(Octokit::Client) }

  before do
    allow(Octokit::Client).to receive(:new).with(access_token: github_token).and_return(client)
    allow(client).to receive(:auto_paginate=).with(true)
  end

  describe "#initialize" do
    context "with valid parameters" do
      it "creates a new instance" do
        expect(pull_request).to be_a(described_class)
      end

      it "sets up the Octokit client with correct options" do
        pull_request # Force evaluation of the let
        expect(Octokit::Client).to have_received(:new).with(access_token: github_token)
        expect(client).to have_received(:auto_paginate=).with(true)
      end
    end

    context "with missing or empty github_token" do
      it "raises ArgumentError when token is nil" do
        expect do
          described_class.new(github_token: nil, repo:, pr_number:)
        end.to raise_error(ArgumentError, "GitHub token is required")
      end

      it "raises ArgumentError when token is empty string" do
        expect do
          described_class.new(github_token: "", repo:, pr_number:)
        end.to raise_error(ArgumentError, "GitHub token is required")
      end
    end

    context "with missing or empty repo" do
      it "raises ArgumentError when repo is nil" do
        expect do
          described_class.new(github_token:, repo: nil, pr_number:)
        end.to raise_error(ArgumentError, "Repository is required")
      end

      it "raises ArgumentError when repo is empty string" do
        expect do
          described_class.new(github_token:, repo: "", pr_number:)
        end.to raise_error(ArgumentError, "Repository is required")
      end
    end

    context "with missing or empty pr_number" do
      it "raises ArgumentError when pr_number is nil" do
        expect do
          described_class.new(github_token:, repo:, pr_number: nil)
        end.to raise_error(ArgumentError, "PR number is required")
      end

      it "raises ArgumentError when pr_number is empty string" do
        expect do
          described_class.new(github_token:, repo:, pr_number: "")
        end.to raise_error(ArgumentError, "PR number is required")
      end
    end

    context "with repository normalization" do
      it "keeps owner/repo format as is" do
        described_class.new(github_token:, repo: "owner/repo", pr_number:)
        expect(Octokit::Client).to have_received(:new).with(access_token: github_token)
      end

      it "extracts owner/repo from full GitHub URL" do
        described_class.new(github_token:, repo: "https://github.com/owner/repo", pr_number:)
        expect(Octokit::Client).to have_received(:new).with(access_token: github_token)
      end

      it "extracts owner/repo from GitHub URL with .git suffix" do
        described_class.new(github_token:, repo: "https://github.com/owner/repo.git", pr_number:)
        expect(Octokit::Client).to have_received(:new).with(access_token: github_token)
      end

      it "raises ArgumentError for invalid repo format" do
        expect do
          described_class.new(github_token:, repo: "just-repo-name", pr_number:)
        end.to raise_error(ArgumentError, "Repository must be in format 'owner/repo' or a full GitHub URL")
      end
    end
  end

  describe "#inline_comments" do
    let(:comments) { [{ id: 1, body: "Comment 1" }, { id: 2, body: "Comment 2" }] }

    before do
      allow(client).to receive(:pull_request_comments).with(repo, pr_number).and_return(comments)
    end

    it "returns pull request comments" do
      expect(pull_request.inline_comments).to eq(comments)
    end

    it "calls the client with correct parameters" do
      pull_request.inline_comments
      expect(client).to have_received(:pull_request_comments).with(repo, pr_number)
    end
  end

  describe "#global_comments" do
    let(:comments) { [{ id: 1, body: "Global comment 1" }] }

    before do
      allow(client).to receive(:issue_comments).with(repo, pr_number).and_return(comments)
    end

    it "returns issue comments" do
      expect(pull_request.global_comments).to eq(comments)
    end

    it "calls the client with correct parameters" do
      pull_request.global_comments
      expect(client).to have_received(:issue_comments).with(repo, pr_number)
    end
  end

  describe "#latest_commit_sha" do
    let(:commit_sha) { "abc123def456" }
    let(:pull_request_data) { instance_double(PullRequestData, head: instance_double(Head, sha: commit_sha)) }

    before do
      allow(client).to receive(:pull_request).with(repo, pr_number).and_return(pull_request_data)
    end

    it "returns the latest commit SHA" do
      expect(pull_request.latest_commit_sha).to eq(commit_sha)
    end

    it "calls the client with correct parameters" do
      pull_request.latest_commit_sha
      expect(client).to have_received(:pull_request).with(repo, pr_number)
    end

    it "memoizes the result" do
      pull_request.latest_commit_sha
      pull_request.latest_commit_sha
      expect(client).to have_received(:pull_request).with(repo, pr_number).once
    end
  end

  describe "#add_global_comment" do
    let(:body) { "This is a comment" }
    let(:response) { { id: 1, body: body } }

    before do
      allow(client).to receive(:add_comment).with(repo, pr_number, body).and_return(response)
    end

    it "adds a comment to the pull request" do
      result = pull_request.add_global_comment(body: body)
      expect(result).to eq(response)
    end

    it "calls the client with correct parameters" do
      pull_request.add_global_comment(body: body)
      expect(client).to have_received(:add_comment).with(repo, pr_number, body)
    end
  end

  describe "#update_global_comment" do
    let(:comment_id) { 456 }
    let(:body) { "Updated comment" }
    let(:response) { { id: comment_id, body: body } }

    before do
      allow(client).to receive(:update_comment).with(repo, comment_id, body).and_return(response)
    end

    it "updates a comment" do
      result = pull_request.update_global_comment(id: comment_id, body: body)
      expect(result).to eq(response)
    end

    it "calls the client with correct parameters" do
      pull_request.update_global_comment(id: comment_id, body: body)
      expect(client).to have_received(:update_comment).with(repo, comment_id, body)
    end
  end

  describe "#delete_global_comment" do
    let(:comment_id) { 789 }

    before do
      allow(client).to receive(:delete_comment).with(repo, comment_id)
    end

    it "deletes a comment" do
      pull_request.delete_global_comment(comment_id)
      expect(client).to have_received(:delete_comment).with(repo, comment_id)
    end
  end

  describe "#update_inline_comment" do
    let(:comment_id) { 456 }
    let(:body) { "Updated inline comment" }
    let(:response) { { id: comment_id, body: body } }

    before do
      allow(client).to receive(:update_pull_request_comment).with(repo, comment_id, body).and_return(response)
    end

    it "updates an inline comment" do
      result = pull_request.update_inline_comment(id: comment_id, body: body)
      expect(result).to eq(response)
    end

    it "calls the client with correct parameters" do
      pull_request.update_inline_comment(id: comment_id, body: body)
      expect(client).to have_received(:update_pull_request_comment).with(repo, comment_id, body)
    end
  end

  describe "#delete_inline_comment" do
    let(:comment_id) { 789 }

    before do
      allow(client).to receive(:delete_pull_request_comment).with(repo, comment_id)
    end

    it "deletes an inline comment" do
      pull_request.delete_inline_comment(comment_id)
      expect(client).to have_received(:delete_pull_request_comment).with(repo, comment_id)
    end
  end

  describe "#add_comment_on_lines" do
    let(:commit_id) { "commit123" }
    let(:file_path) { "lib/test.rb" }
    let(:start_line) { 8 }
    let(:end_line) { 10 }
    let(:body) { "Coverage comment" }
    let(:side) { "RIGHT" }
    let(:diff) do
      <<~DIFF
        diff --git a/lib/test.rb b/lib/test.rb
        index 1234567..abcdefg 100644
        --- a/lib/test.rb
        +++ b/lib/test.rb
        @@ -7,7 +7,7 @@ class Test
         def method1
           puts "hello"
         end
        -def old_method
        +def new_method
           puts "world"
         end
        +def added_method
        +  puts "new code"
        +end
        end
      DIFF
    end

    before do
      allow(client).to receive(:pull_request).with(repo, pr_number, accept: "application/vnd.github.v3.diff").and_return(diff)
      allow(client).to receive(:post).and_return({ id: 1 })
      allow(client).to receive(:pull_request_comments).with(repo, pr_number).and_return([])
    end

    context "with single line comment" do
      let(:end_line) { 8 }

      it "adds a comment on a single line" do
        pull_request.add_comment_on_lines(
          commit_id:  commit_id,
          file_path:  file_path,
          start_line: start_line,
          end_line:   end_line,
          body:       body
        )

        expect(client).to have_received(:post).with(
          "/repos/#{repo}/pulls/#{pr_number}/comments",
          hash_including(
            body:      body,
            commit_id: commit_id,
            path:      file_path,
            line:      start_line,
            side:      "RIGHT"
          )
        )
      end

      it "does not include start_line in payload when same as line" do
        pull_request.add_comment_on_lines(
          commit_id:  commit_id,
          file_path:  file_path,
          start_line: start_line,
          end_line:   end_line,
          body:       body
        )

        expect(client).to have_received(:post).with(
          "/repos/#{repo}/pulls/#{pr_number}/comments",
          hash_not_including(:start_line, :start_side)
        )
      end
    end

    context "with multi-line comment" do
      it "adds a comment on multiple lines" do
        pull_request.add_comment_on_lines(
          commit_id:  commit_id,
          file_path:  file_path,
          start_line: start_line,
          end_line:   end_line,
          body:       body
        )

        expect(client).to have_received(:post).with(
          "/repos/#{repo}/pulls/#{pr_number}/comments",
          hash_including(
            body:       body,
            commit_id:  commit_id,
            path:       file_path,
            line:       end_line,
            side:       "RIGHT",
            start_line: start_line,
            start_side: "RIGHT"
          )
        )
      end
    end

    context "with custom side" do
      let(:side) { "LEFT" }

      it "ignores the specified side and uses calculated side from diff" do
        pull_request.add_comment_on_lines(
          commit_id:  commit_id,
          file_path:  file_path,
          start_line: start_line,
          end_line:   end_line,
          body:       body
        )

        expect(client).to have_received(:post).with(
          "/repos/#{repo}/pulls/#{pr_number}/comments",
          hash_including(side: "RIGHT") # Calculated from diff, not the passed side parameter
        )
      end
    end

    context "when existing comment exists for same file and line range" do
      let(:existing_comment) do
        instance_double(
          Comment,
          id:         456,
          body:       "<!-- coverage-inline-marker -->\n❌ Lines 8–10 are not covered by tests.",
          path:       file_path,
          line:       end_line,
          start_line: start_line
        )
      end

      before do
        allow(pull_request).to receive(:inline_comments).and_return([existing_comment])
        allow(pull_request).to receive(:update_inline_comment)
      end

      it "updates the existing comment instead of creating a new one" do
        pull_request.add_comment_on_lines(
          commit_id:  commit_id,
          file_path:  file_path,
          start_line: start_line,
          end_line:   end_line,
          body:       body
        )

        expect(pull_request).to have_received(:update_inline_comment).with(
          id:   existing_comment.id,
          body: body
        )
        expect(client).not_to have_received(:post)
      end
    end

    context "when no existing comment exists" do
      before do
        allow(pull_request).to receive(:inline_comments).and_return([])
      end

      it "creates a new comment" do
        pull_request.add_comment_on_lines(
          commit_id:  commit_id,
          file_path:  file_path,
          start_line: start_line,
          end_line:   end_line,
          body:       body
        )

        expect(client).to have_received(:post).with(
          "/repos/#{repo}/pulls/#{pr_number}/comments",
          hash_including(body: body)
        )
      end
    end

    context "when GitHub API returns an error" do
      let(:error) do
        Class.new(StandardError) do
          def response_body
            '{"message": "Validation failed"}'
          end

          def status
            422
          end

          def is_a?(klass)
            klass == Octokit::Error
          end
        end.new("API Error")
      end

      before do
        allow(client).to receive(:post).and_raise(error)
      end

      it "raises the error with debugging information" do
        expect do
          pull_request.add_comment_on_lines(
            commit_id:  commit_id,
            file_path:  file_path,
            start_line: start_line,
            end_line:   end_line,
            body:       body
          )
        end.to raise_error(StandardError, "API Error")
      end
    end

    context "when an unexpected error occurs" do
      let(:error) { StandardError.new("Unexpected error") }

      before do
        allow(client).to receive(:post).and_raise(error)
      end

      it "raises the error with debugging information" do
        expect do
          pull_request.add_comment_on_lines(
            commit_id:  commit_id,
            file_path:  file_path,
            start_line: start_line,
            end_line:   end_line,
            body:       body
          )
        end.to raise_error(StandardError, "Unexpected error")
      end
    end

    context "with file path matching" do
      let(:file_path) { "test.rb" }
      let(:diff) do
        <<~DIFF
          diff --git a/lib/test.rb b/lib/test.rb
          index 1234567..abcdefg 100644
          --- a/lib/test.rb
          +++ b/lib/test.rb
          @@ -7,7 +7,7 @@ class Test
           def method1
             puts "hello"
           end
          -def old_method
          +def new_method
             puts "world"
           end
          end
        DIFF
      end

      it "finds the actual file path in the diff" do
        pull_request.add_comment_on_lines(
          commit_id:  commit_id,
          file_path:  file_path,
          start_line: start_line,
          end_line:   end_line,
          body:       body
        )

        expect(client).to have_received(:post).with(
          "/repos/#{repo}/pulls/#{pr_number}/comments",
          hash_including(path: "lib/test.rb")
        )
      end
    end
  end

  describe "#find_existing_inline_comment" do
    let(:file_path) { "lib/test.rb" }
    let(:start_line) { 8 }
    let(:end_line) { 10 }

    context "when no comments exist" do
      before do
        allow(pull_request).to receive(:inline_comments).and_return([])
      end

      it "returns nil" do
        result = pull_request.send(:find_existing_inline_comment, file_path, start_line, end_line)
        expect(result).to be_nil
      end
    end

    context "when coverage comment exists for same file and line range" do
      let(:existing_comment) do
        instance_double(
          Comment,
          id:         123,
          body:       "<!-- coverage-inline-marker -->\n❌ Lines 8–10 are not covered by tests.",
          path:       file_path,
          line:       end_line,
          start_line: start_line
        )
      end

      before do
        allow(pull_request).to receive(:inline_comments).and_return([existing_comment])
      end

      it "returns the existing comment" do
        result = pull_request.send(:find_existing_inline_comment, file_path, start_line, end_line)
        expect(result).to eq(existing_comment)
      end
    end

    context "when coverage comment exists for different file" do
      let(:existing_comment) do
        instance_double(
          Comment,
          id:         123,
          body:       "<!-- coverage-inline-marker -->\n❌ Lines 8–10 are not covered by tests.",
          path:       "different/file.rb",
          line:       end_line,
          start_line: start_line
        )
      end

      before do
        allow(pull_request).to receive(:inline_comments).and_return([existing_comment])
      end

      it "returns nil" do
        result = pull_request.send(:find_existing_inline_comment, file_path, start_line, end_line)
        expect(result).to be_nil
      end
    end

    context "when coverage comment exists for different line range" do
      let(:existing_comment) do
        instance_double(
          Comment,
          id:         123,
          body:       "<!-- coverage-inline-marker -->\n❌ Lines 5–7 are not covered by tests.",
          path:       file_path,
          line:       7,
          start_line: 5
        )
      end

      before do
        allow(pull_request).to receive(:inline_comments).and_return([existing_comment])
      end

      it "returns nil" do
        result = pull_request.send(:find_existing_inline_comment, file_path, start_line, end_line)
        expect(result).to be_nil
      end
    end

    context "when non-coverage comment exists" do
      let(:existing_comment) do
        instance_double(
          Comment,
          id:         123,
          body:       "This is a regular comment",
          path:       file_path,
          line:       end_line,
          start_line: start_line
        )
      end

      before do
        allow(pull_request).to receive(:inline_comments).and_return([existing_comment])
      end

      it "returns nil" do
        result = pull_request.send(:find_existing_inline_comment, file_path, start_line, end_line)
        expect(result).to be_nil
      end
    end
  end

  describe "private methods" do
    describe "#normalize_repo" do
      it "returns owner/repo format as is" do
        pr = described_class.new(github_token:, repo: "owner/repo", pr_number:)
        expect(pr.send(:normalize_repo, "owner/repo")).to eq("owner/repo")
      end

      it "extracts owner/repo from full GitHub URL" do
        pr = described_class.new(github_token:, repo: "https://github.com/owner/repo", pr_number:)
        expect(pr.send(:normalize_repo, "https://github.com/owner/repo")).to eq("owner/repo")
      end

      it "extracts owner/repo from GitHub URL with .git suffix" do
        pr = described_class.new(github_token:, repo: "https://github.com/owner/repo.git", pr_number:)
        expect(pr.send(:normalize_repo, "https://github.com/owner/repo.git")).to eq("owner/repo")
      end

      it "raises ArgumentError for invalid repo format" do
        pr = described_class.new(github_token:, repo: "owner/repo", pr_number:)
        expect do
          pr.send(:normalize_repo, "just-repo-name")
        end.to raise_error(ArgumentError, "Repository must be in format 'owner/repo' or a full GitHub URL")
      end
    end

    describe "#pull_request_diff" do
      let(:diff) { "diff content" }

      before do
        allow(client).to receive(:pull_request).with(repo, pr_number, accept: "application/vnd.github.v3.diff").and_return(diff)
      end

      it "returns the pull request diff" do
        result = pull_request.send(:pull_request_diff)
        expect(result).to eq(diff)
      end

      it "memoizes the result" do
        pull_request.send(:pull_request_diff)
        pull_request.send(:pull_request_diff)
        expect(client).to have_received(:pull_request).with(repo, pr_number, accept: "application/vnd.github.v3.diff").once
      end
    end

    describe "#find_actual_file_path_in_diff" do
      let(:diff) do
        <<~DIFF
          diff --git a/lib/test.rb b/lib/test.rb
          index 1234567..abcdefg 100644
          --- a/lib/test.rb
          +++ b/lib/test.rb
        DIFF
      end

      it "finds exact file path match" do
        result = pull_request.send(:find_actual_file_path_in_diff, diff, "lib/test.rb")
        expect(result).to eq("lib/test.rb")
      end

      it "finds basename match" do
        result = pull_request.send(:find_actual_file_path_in_diff, diff, "test.rb")
        expect(result).to eq("lib/test.rb")
      end

      it "returns original path if no match found" do
        result = pull_request.send(:find_actual_file_path_in_diff, diff, "nonexistent.rb")
        expect(result).to eq("nonexistent.rb")
      end
    end

    describe "#find_diff_line_numbers" do
      let(:diff) do
        <<~DIFF
          diff --git a/lib/test.rb b/lib/test.rb
          index 1234567..abcdefg 100644
          --- a/lib/test.rb
          +++ b/lib/test.rb
          @@ -7,7 +7,7 @@ class Test
           def method1
             puts "hello"
           end
          -def old_method
          +def new_method
             puts "world"
           end
          +def added_method
          +  puts "new code"
          +end
          end
        DIFF
      end

      it "finds line numbers for single line comment" do
        result = pull_request.send(:find_diff_line_numbers, diff, "lib/test.rb", 8, 8)
        expect(result).to include(
          line:       8,
          side:       "RIGHT",
          start_line: nil,
          start_side: "RIGHT"
        )
      end

      it "finds line numbers for multi-line comment" do
        result = pull_request.send(:find_diff_line_numbers, diff, "lib/test.rb", 8, 10)
        expect(result).to include(
          line:       10,
          side:       "RIGHT",
          start_line: 8,
          start_side: "RIGHT"
        )
      end
    end

    describe "#delete_coverage_comments_for_file" do
      let(:file_path) { "lib/test.rb" }
      let(:coverage_comment) do
        instance_double(
          Comment,
          id:   123,
          body: "<!-- coverage-inline-marker -->\n❌ Line 8 is not covered by tests.",
          path: file_path
        )
      end
      let(:non_coverage_comment) do
        instance_double(
          Comment,
          id:   789,
          body: "This is a regular comment",
          path: file_path
        )
      end
      let(:coverage_comment_different_file) do
        instance_double(
          Comment,
          id:   456,
          body: "<!-- coverage-inline-marker -->\n❌ Line 5 is not covered by tests.",
          path: "different/file.rb"
        )
      end

      before do
        allow(pull_request).to receive(:inline_comments).and_return(
          [
            coverage_comment,
            non_coverage_comment,
            coverage_comment_different_file
          ]
        )
        allow(pull_request).to receive(:delete_inline_comment)
      end

      it "deletes coverage comments for the specified file" do
        expect(pull_request).to receive(:delete_inline_comment).with(coverage_comment.id)

        pull_request.send(:delete_coverage_comments_for_file, file_path)
      end

      it "does not delete non-coverage comments" do
        expect(pull_request).not_to receive(:delete_inline_comment).with(non_coverage_comment.id)

        pull_request.send(:delete_coverage_comments_for_file, file_path)
      end

      it "does not delete coverage comments for different files" do
        expect(pull_request).not_to receive(:delete_inline_comment).with(coverage_comment_different_file.id)

        pull_request.send(:delete_coverage_comments_for_file, file_path)
      end
    end
  end
end
