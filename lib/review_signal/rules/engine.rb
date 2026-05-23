# frozen_string_literal: true

require "yaml"
require_relative "patch_evidence"

module ReviewSignal
  module Rules
    RiskFlag = Struct.new(:id, :severity, :message, :review_focus, :evidence, keyword_init: true)

    class Engine
      attr_reader :config

      def self.merge(base_config, override_config)
        base_rules = Array(base_config.fetch("rules", []))
        override_rules = Array(override_config.fetch("rules", []))
        rules_by_id = base_rules.each_with_object({}) { |rule, rules| rules[rule.fetch("id")] = rule }

        override_rules.each do |rule|
          rules_by_id[rule.fetch("id")] = rule
        end

        { "rules" => rules_by_id.values }
      end

      def initialize(config)
        @config = config
      end

      def flags_for(files, patches: {})
        rules.filter_map do |rule|
          evidence = collect_evidence(rule, files, patches)
          next if evidence.empty?

          RiskFlag.new(
            id: rule.fetch("id"),
            severity: rule.fetch("severity", "medium"),
            message: rule.fetch("message"),
            review_focus: Array(rule["review_focus"]),
            evidence: evidence
          )
        end
      end

      private

      def rules
        Array(config.fetch("rules", []))
      end

      def collect_evidence(rule, files, patches)
        condition = rule.fetch("when", {})
        any_path = condition["any_path"]
        any_patch = condition["any_patch"]
        return [] if any_path.nil? && any_patch.nil?

        path_matches = matching_paths(any_path, files)
        return [] if any_path && path_matches.empty?

        if any_patch
          limit = any_path ? path_matches : nil
          return PatchEvidence.from_patches(any_patch, patches, limit_to_files: limit)
        end

        PatchEvidence.from_paths(path_matches)
      end

      def matching_paths(any_path, files)
        patterns = Array(any_path)
        files.select do |path|
          patterns.any? { |pattern| glob_match?(pattern, path) }
        end
      end

      def glob_match?(pattern, path)
        if pattern.end_with?("/**")
          path.start_with?("#{pattern.delete_suffix('/**')}/")
        else
          File.fnmatch?(pattern, path, File::FNM_PATHNAME | File::FNM_EXTGLOB)
        end
      end
    end
  end
end
