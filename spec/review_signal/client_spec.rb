# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReviewSignal::Client do
  class FakeApi
    attr_reader :calls

    def initialize
      @calls = []
    end

    def pull_request(repo, pr_number)
      calls << [:pull_request, repo, pr_number]
      { title: "PR" }
    end

    def pull_request_files(repo, pr_number)
      calls << [:pull_request_files, repo, pr_number]
      [{ filename: "app/models/user.rb" }]
    end

    def issue_comments(repo, pr_number)
      calls << [:issue_comments, repo, pr_number]
      []
    end
  end

  it "delegates PR metadata and file reads to the API client" do
    api = FakeApi.new
    client = described_class.new(api: api)

    expect(client.pull_request("owner/repo", 1)).to eq(title: "PR")
    expect(client.pull_request_files("owner/repo", 1)).to eq([{ filename: "app/models/user.rb" }])
    expect(client.issue_comments("owner/repo", 1)).to eq([])
    expect(api.calls).to eq([
      [:pull_request, "owner/repo", 1],
      [:pull_request_files, "owner/repo", 1],
      [:issue_comments, "owner/repo", 1]
    ])
  end
end

