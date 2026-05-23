# frozen_string_literal: true

require "base64"
require "yaml"

module ReviewSignal
  class ConfigLoader
    PRESET_FILES = {
      "default" => "rules/default_rules.yml",
      "rails" => "rules/rails_rules.yml"
    }.freeze

    attr_reader :preset, :config_path, :mode, :client, :repo, :base_ref

    def initialize(preset:, config_path: nil, mode: "cli", client: nil, repo: nil, base_ref: nil)
      @preset = preset
      @config_path = blank?(config_path) ? nil : config_path
      @mode = mode
      @client = client
      @repo = repo
      @base_ref = base_ref
    end

    def load
      base = load_preset
      return base unless config_path

      override = action_mode? ? load_remote_config : load_filesystem_config
      ReviewSignal::Rules::Engine.merge(base, override)
    rescue StandardError => error
      return base if not_found?(error)

      raise
    end

    private

    def load_preset
      default_config = load_preset_file("default")

      return default_config if preset == "default"

      ReviewSignal::Rules::Engine.merge(default_config, load_preset_file(preset))
    end

    def load_preset_file(preset_name)
      relative_path = PRESET_FILES.fetch(preset_name) do
        raise ArgumentError, "Unknown preset file: #{preset_name}"
      end

      load_yaml(File.read(File.expand_path(relative_path, __dir__)))
    end

    def load_filesystem_config
      load_yaml(File.read(config_path))
    end

    def load_remote_config
      raise ArgumentError, "client, repo, and base_ref are required in action mode" unless client && repo && base_ref

      content = client.contents(repo, path: config_path, ref: base_ref)
      raw_content = value_from(content, :content)
      load_yaml(Base64.decode64(raw_content.to_s.delete("\n")))
    end

    def load_yaml(raw_yaml)
      YAML.safe_load(raw_yaml, permitted_classes: [], aliases: false) || {}
    end

    def value_from(object, key)
      return object[key] if object.respond_to?(:key?) && object.key?(key)
      return object[key.to_s] if object.respond_to?(:key?) && object.key?(key.to_s)
      return object.public_send(key) if object.respond_to?(key)

      nil
    end

    def action_mode?
      mode == "action"
    end

    def not_found?(error)
      error.class.name == "Octokit::NotFound" || (error.respond_to?(:status) && error.status == 404)
    end

    def blank?(value)
      value.nil? || value.to_s.strip.empty?
    end
  end
end

