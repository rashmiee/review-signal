# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReviewSignal::Analyzers::TestSignal do
  it "maps app code to direct spec paths" do
    signal = described_class.new(["app/services/billing/charge_customer.rb"])

    expect(signal.expected_spec_path("app/services/billing/charge_customer.rb"))
      .to eq("spec/services/billing/charge_customer_spec.rb")
  end

  it "reports app files without direct spec changes" do
    files = [
      "app/models/user.rb",
      "app/services/create_user.rb",
      "spec/models/user_spec.rb"
    ]

    expect(described_class.new(files).files_without_direct_spec_change)
      .to eq(["app/services/create_user.rb"])
  end

  it "ignores non-app and spec-only changes" do
    files = ["README.md", "spec/models/user_spec.rb"]

    expect(described_class.new(files).files_without_direct_spec_change).to be_empty
  end
end

