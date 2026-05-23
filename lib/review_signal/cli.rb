# frozen_string_literal: true

require "optparse"

module ReviewSignal
  class Cli
    def self.call(argv = ARGV, out: $stdout, err: $stderr)
      new(argv, out: out, err: err).call
    end

    attr_reader :argv, :out, :err

    def initialize(argv, out:, err:)
      @argv = argv
      @out = out
      @err = err
    end

    def call
      options = parse_options
      repo = options.fetch(:repo) { ENV.fetch("GITHUB_REPOSITORY") }
      pr_number = Integer(options.fetch(:pr_number) { ENV.fetch("PR_NUMBER") })
      preset = options.fetch(:preset) { ENV.fetch("REVIEW_SIGNAL_PRESET", "rails") }
      config_path = options.fetch(:config_path) { ENV["REVIEW_SIGNAL_CONFIG"] }
      mode = ENV.fetch("REVIEW_SIGNAL_MODE", "cli")
      token = ENV["GITHUB_TOKEN"]

      client = Client.new(token: token)
      pull_request = client.pull_request(repo, pr_number)
      files = client.pull_request_files(repo, pr_number).map { |file| value_from(file, :filename) }
      context = PullRequestContext.new(
        repo: repo,
        number: pr_number,
        title: value_from(pull_request, :title),
        base_sha: value_from(value_from(pull_request, :base), :sha),
        head_sha: value_from(value_from(pull_request, :head), :sha),
        files: files
      )

      config = ConfigLoader.new(
        preset: preset,
        config_path: config_path,
        mode: mode,
        client: client,
        repo: repo,
        base_ref: context.base_sha
      ).load

      area_summary = Analyzers::AreaClassifier.new(files).summary
      risk_flags = Rules::Engine.new(config).flags_for(files)
      test_signal = Analyzers::TestSignal.new(files)
      markdown = Render::MarkdownBrief.new(
        context: context,
        area_summary: area_summary,
        risk_flags: risk_flags,
        test_signal: test_signal
      ).render

      if options[:dry_run]
        out.write(markdown)
      else
        result = Services::UpsertComment.new(client: client, repo: repo, pr_number: pr_number).call(markdown)
        out.puts("Review Signal comment #{result.status}")
      end

      0
    rescue KeyError, ArgumentError => error
      err.puts("review-signal: #{error.message}")
      1
    end

    private

    def parse_options
      options = {}

      OptionParser.new do |parser|
        parser.banner = "Usage: review-signal [options]"
        parser.on("--repo REPO", "GitHub repository in owner/name form") { |value| options[:repo] = value }
        parser.on("--pr NUMBER", Integer, "Pull request number") { |value| options[:pr_number] = value }
        parser.on("--preset PRESET", "Built-in preset: default or rails") { |value| options[:preset] = value }
        parser.on("--config PATH", "Local rules YAML in CLI mode") { |value| options[:config_path] = value }
        parser.on("--dry-run", "Print markdown instead of posting a comment") { options[:dry_run] = true }
      end.parse!(argv)

      options
    end

    def value_from(object, key)
      return nil unless object
      return object[key] if object.respond_to?(:key?) && object.key?(key)
      return object[key.to_s] if object.respond_to?(:key?) && object.key?(key.to_s)
      return object.public_send(key) if object.respond_to?(key)

      nil
    end
  end
end

