# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReviewSignal::Services::UpsertComment do
  class FakeCommentClient
    attr_reader :comments, :updates, :creates

    def initialize(comments)
      @comments = comments
      @updates = []
      @creates = []
    end

    def issue_comments(_repo, _pr_number)
      comments
    end

    def update_issue_comment(repo, comment_id, body)
      updates << { repo: repo, comment_id: comment_id, body: body }
    end

    def create_issue_comment(repo, pr_number, body)
      creates << { repo: repo, pr_number: pr_number, body: body }
      { id: 99, body: body }
    end
  end

  it "skips updates when the marker comment body is unchanged after normalization" do
    body = "#{ReviewSignal::Render::MarkdownBrief::MARKER}\n## Review Signal\n"
    client = FakeCommentClient.new([{ id: 1, body: "#{body}\n" }])

    result = described_class.new(client: client, repo: "owner/repo", pr_number: 5).call(body)

    expect(result.status).to eq(:unchanged)
    expect(client.updates).to be_empty
  end

  it "updates an existing marker comment when the body changed" do
    client = FakeCommentClient.new([{ id: 1, body: "#{ReviewSignal::Render::MarkdownBrief::MARKER}\nold\n" }])

    result = described_class.new(client: client, repo: "owner/repo", pr_number: 5).call(
      "#{ReviewSignal::Render::MarkdownBrief::MARKER}\nnew\n"
    )

    expect(result.status).to eq(:updated)
    expect(client.updates).to contain_exactly(include(comment_id: 1))
  end

  it "creates a new comment when no marker exists" do
    client = FakeCommentClient.new([])

    result = described_class.new(client: client, repo: "owner/repo", pr_number: 5).call(
      "#{ReviewSignal::Render::MarkdownBrief::MARKER}\nnew\n"
    )

    expect(result.status).to eq(:created)
    expect(result.comment_id).to eq(99)
    expect(client.creates).to contain_exactly(include(pr_number: 5))
  end
end

