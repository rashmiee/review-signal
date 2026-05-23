# frozen_string_literal: true

module ReviewSignal
  module Analyzers
    class AreaClassifier
      BUCKETS = {
        migrations: ["db/migrate/**"],
        models: ["app/models/**", "engines/**/app/models/**"],
        controllers: ["app/controllers/**", "engines/**/app/controllers/**"],
        views: ["app/views/**", "engines/**/app/views/**", "**/*.haml"],
        services: ["app/services/**", "engines/**/app/services/**"],
        jobs: ["app/jobs/**", "engines/**/app/jobs/**"],
        policies: ["app/policies/**", "app/models/ability/**", "config/roles.yml"],
        graphql: ["app/graphql/**"],
        client: ["client/**", "app/javascript/**"],
        specs: ["spec/**", "test/**", "features/**", "client/tests/**"],
        config: ["config/**", ".github/**", "Gemfile", "Gemfile.lock", "*.gemspec", "package.json", "yarn.lock"]
      }.freeze

      attr_reader :files

      def initialize(files)
        @files = files
      end

      def summary
        files.each_with_object(Hash.new(0)) do |path, counts|
          counts[classify(path)] += 1
        end.sort.to_h
      end

      def classify(path)
        BUCKETS.each do |bucket, patterns|
          return bucket if patterns.any? { |pattern| glob_match?(pattern, path) }
        end

        :other
      end

      private

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

