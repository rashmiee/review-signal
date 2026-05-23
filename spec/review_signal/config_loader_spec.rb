# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe ReviewSignal::ConfigLoader do
  it "loads the built-in Rails preset" do
    config = described_class.new(preset: "rails").load

    expect(config.fetch("rules").map { |rule| rule.fetch("id") }).to include("migration", "auth_surface")
  end

  it "merges local filesystem overrides in CLI mode" do
    file = Tempfile.new("review_signal")
    file.write <<~YAML
      rules:
        - id: migration
          severity: critical
          message: Override migration message.
    YAML
    file.close

    config = described_class.new(preset: "rails", config_path: file.path).load

    expect(config.fetch("rules")).to include(include("id" => "migration", "severity" => "critical"))
  ensure
    file&.unlink
  end

  it "loads remote config from the trusted base ref in action mode" do
    client = Class.new do
      attr_reader :request

      def contents(repo, path:, ref:)
        @request = { repo: repo, path: path, ref: ref }
        Struct.new(:content).new(
          Base64.strict_encode64(<<~YAML)
            rules:
              - id: custom
                when:
                  any_path: "lib/**"
                severity: medium
                message: Custom rule.
          YAML
        )
      end
    end.new

    config = described_class.new(
      preset: "default",
      config_path: ".github/review_signal.yml",
      mode: "action",
      client: client,
      repo: "owner/repo",
      base_ref: "abc123"
    ).load

    expect(client.request).to eq(repo: "owner/repo", path: ".github/review_signal.yml", ref: "abc123")
    expect(config.fetch("rules")).to include(include("id" => "custom"))
  end
end
