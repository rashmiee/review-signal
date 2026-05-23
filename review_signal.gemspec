# frozen_string_literal: true

require_relative "lib/review_signal/version"

Gem::Specification.new do |spec|
  spec.name = "review_signal"
  spec.version = ReviewSignal::VERSION
  spec.authors = ["Rashmi Prabha"]
  spec.email = ["replace-with-support-email@example.com"]

  spec.summary = "Deterministic PR review briefs for GitHub pull requests."
  spec.description = "Review Signal posts a stable, path-aware review brief comment on GitHub pull requests."
  spec.homepage = "https://github.com/rashmiee/review-signal"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/releases"

  spec.files = Dir.chdir(__dir__) do
    Dir["lib/**/*", "bin/*", "README.md", "LICENSE", "action.yml"]
  end
  spec.bindir = "bin"
  spec.executables = ["review-signal"]
  spec.require_paths = ["lib"]

  spec.add_dependency "octokit", "~> 9.0"
  spec.add_dependency "base64", "~> 0.2"

  spec.add_development_dependency "rspec", "~> 3.13"
end
