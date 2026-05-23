# frozen_string_literal: true

module ReviewSignal
  module Rules
    Evidence = Struct.new(:path, :snippet, keyword_init: true)

    module PatchEvidence
      module_function

      SNIPPET_LIMIT = 120

      def from_paths(paths)
        paths.map { |path| Evidence.new(path: path) }
      end

      def from_patches(patterns, patches, limit_to_files: nil)
        evidence = []

        patches.each do |path, patch|
          next if patch.nil? || patch.empty?
          next if limit_to_files && !limit_to_files.include?(path)

          Array(patterns).each do |pattern|
            regex = Regexp.new(pattern, Regexp::MULTILINE)
            snippet = snippet_for_patch(regex, patch)
            next unless snippet

            evidence << Evidence.new(path: path, snippet: snippet)
          end
        end

        evidence.uniq { |item| [item.path, item.snippet] }
      end

      def snippet_for_patch(regex, patch)
        added_lines = patch.each_line.filter_map do |line|
          next unless line.start_with?("+") && !line.start_with?("+++")

          line.delete_prefix("+").rstrip
        end

        added_lines.each do |line|
          return truncate(line) if regex.match?(line)
        end

        added_text = added_lines.join("\n")
        match = regex.match(added_text)
        return unless match

        line_index = added_text[0...match.begin(0)].count("\n")
        snippet_lines = added_lines[line_index, 2] || [match[0].strip]
        truncate(snippet_lines.join(" / "))
      end

      def truncate(text)
        cleaned = text.gsub(/\s+/, " ").strip
        return cleaned if cleaned.length <= SNIPPET_LIMIT

        "#{cleaned[0, SNIPPET_LIMIT - 3]}..."
      end
    end
  end
end
