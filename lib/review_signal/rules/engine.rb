# frozen_string_literal: true

require "yaml"

module ReviewSignal
  module Rules
    RiskFlag = Struct.new(:id, :severity, :message, :review_focus, keyword_init: true)

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

      def flags_for(files)
        rules.filter_map do |rule|
          next unless matches?(rule, files)

          RiskFlag.new(
            id: rule.fetch("id"),
            severity: rule.fetch("severity", "medium"),
            message: rule.fetch("message"),
            review_focus: Array(rule["review_focus"])
          )
        end
      end

      private

      def rules
        Array(config.fetch("rules", []))
      end

      def matches?(rule, files)
        condition = rule.fetch("when", {})
        any_path = condition["any_path"]
        return false unless any_path

        patterns = Array(any_path)
        files.any? do |path|
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

