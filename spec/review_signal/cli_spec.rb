# frozen_string_literal: true

require "spec_helper"
require "review_signal/cli"
require "stringio"

RSpec.describe ReviewSignal::Cli do
  class FakeCliClient
    def pull_request(_repo, _pr_number)
      {
        title: "Add users",
        base: { sha: "base123" },
        head: { sha: "head123" }
      }
    end

    def pull_request_files(_repo, _pr_number)
      [
        { filename: "app/models/user.rb" },
        { filename: "db/migrate/20260101000000_create_users.rb" }
      ]
    end
  end

  it "prints a dry-run brief" do
    output = StringIO.new

    allow(ReviewSignal::Client).to receive(:new).and_return(FakeCliClient.new)
    status = described_class.call(
      ["--repo", "owner/repo", "--pr", "1", "--preset", "rails", "--dry-run"],
      out: output,
      err: StringIO.new
    )

    expect(status).to eq(0)
    expect(output.string).to include("## Review Signal")
    expect(output.string).to include("No direct spec change detected for:")
  end
end
