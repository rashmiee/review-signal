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
end

