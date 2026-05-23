# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReviewSignal::Rules::Engine do
  it "emits flags for matching paths" do
    config = {
      "rules" => [
        {
          "id" => "migration",
          "when" => { "any_path" => "db/migrate/**" },
          "severity" => "high",
          "message" => "Schema change detected.",
          "review_focus" => ["Confirm rollback path."]
        }
      ]
    }

    flags = described_class.new(config).flags_for(["db/migrate/20260101000000_add_users.rb"])

    expect(flags.map(&:id)).to eq(["migration"])
    expect(flags.first.severity).to eq("high")
  end

  it "merges override rules by id while preserving new rules" do
    base = { "rules" => [{ "id" => "migration", "severity" => "high" }] }
    override = { "rules" => [{ "id" => "migration", "severity" => "critical" }, { "id" => "billing" }] }

    merged = described_class.merge(base, override)

    expect(merged.fetch("rules")).to contain_exactly(
      include("id" => "migration", "severity" => "critical"),
      include("id" => "billing")
    )
  end

  it "emits flags for matching patch content" do
    config = {
      "rules" => [
        {
          "id" => "hardcoded_secret",
          "when" => { "any_patch" => "ADMIN_TOKEN" },
          "severity" => "critical",
          "message" => "Possible hardcoded secret detected in the diff."
        }
      ]
    }

    flags = described_class.new(config).flags_for(
      ["app/controllers/api/v1/task_assignees_controller.rb"],
      patches: {
        "app/controllers/api/v1/task_assignees_controller.rb" => "+      ADMIN_TOKEN = \"secret\"\n"
      }
    )

    expect(flags.map(&:id)).to eq(["hardcoded_secret"])
    expect(flags.first.evidence.first.path).to eq("app/controllers/api/v1/task_assignees_controller.rb")
    expect(flags.first.evidence.first.snippet).to include("ADMIN_TOKEN")
  end
end

