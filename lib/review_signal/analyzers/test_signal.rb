# frozen_string_literal: true

module ReviewSignal
  module Analyzers
    class TestSignal
      SPEC_ELIGIBLE_PREFIXES = %w[
        app/controllers/
        app/graphql/
        app/jobs/
        app/mailers/
        app/models/
        app/policies/
        app/services/
      ].freeze

      attr_reader :files

      def initialize(files)
        @files = files
      end

      def files_without_direct_spec_change
        app_code_files.reject do |path|
          files.include?(expected_spec_path(path))
        end
      end

      def expected_spec_path(path)
        path.sub(%r{\Aapp/}, "spec/").sub(/\.rb\z/, "_spec.rb")
      end

      private

      def app_code_files
        files.select do |path|
          path.end_with?(".rb") && SPEC_ELIGIBLE_PREFIXES.any? { |prefix| path.start_with?(prefix) }
        end
      end
    end
  end
end

