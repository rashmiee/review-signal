# frozen_string_literal: true

require "spec_helper"

RSpec.describe ReviewSignal::Analyzers::AreaClassifier do
  it "classifies migration and model changes" do
    files = ["db/migrate/20260101_add_foo.rb", "app/models/foo.rb"]

    expect(described_class.new(files).summary).to include(migrations: 1, models: 1)
  end

  it "uses the first matching Rails-aware bucket" do
    classifier = described_class.new([])

    expect(classifier.classify("app/controllers/admin/users_controller.rb")).to eq(:controllers)
    expect(classifier.classify("app/views/users/index.html.haml")).to eq(:views)
    expect(classifier.classify("spec/models/user_spec.rb")).to eq(:specs)
  end

  it "falls back to other for unmatched paths" do
    expect(described_class.new(["docs/notes.md"]).summary).to eq(other: 1)
  end
end

