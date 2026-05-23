# frozen_string_literal: true

module ReviewSignal
  module Services
    UpsertResult = Struct.new(:status, :comment_id, keyword_init: true)

    class UpsertComment
      attr_reader :client, :repo, :pr_number, :marker

      def initialize(client:, repo:, pr_number:, marker: Render::MarkdownBrief::MARKER)
        @client = client
        @repo = repo
        @pr_number = pr_number
        @marker = marker
      end

      def call(body)
        normalized_body = normalize(body)
        existing = client.issue_comments(repo, pr_number).find do |comment|
          body_for(comment).include?(marker)
        end

        if existing && normalize(body_for(existing)) == normalized_body
          UpsertResult.new(status: :unchanged, comment_id: id_for(existing))
        elsif existing
          client.update_issue_comment(repo, id_for(existing), normalized_body)
          UpsertResult.new(status: :updated, comment_id: id_for(existing))
        else
          created = client.create_issue_comment(repo, pr_number, normalized_body)
          UpsertResult.new(status: :created, comment_id: id_for(created))
        end
      end

      private

      def normalize(body)
        "#{body.to_s.rstrip}\n"
      end

      def body_for(comment)
        value_for(comment, :body).to_s
      end

      def id_for(comment)
        value_for(comment, :id)
      end

      def value_for(object, key)
        return object[key] if object.respond_to?(:key?) && object.key?(key)
        return object[key.to_s] if object.respond_to?(:key?) && object.key?(key.to_s)
        return object.public_send(key) if object.respond_to?(key)

        nil
      end
    end
  end
end

