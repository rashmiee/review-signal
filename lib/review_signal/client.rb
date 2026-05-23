# frozen_string_literal: true

module ReviewSignal
  class Client
    attr_reader :api

    def initialize(token: nil, api: nil)
      @api = api || build_api(token)
    end

    def pull_request(repo, pr_number)
      api.pull_request(repo, pr_number)
    end

    def pull_request_files(repo, pr_number)
      api.pull_request_files(repo, pr_number)
    end

    def issue_comments(repo, pr_number)
      api.issue_comments(repo, pr_number)
    end

    def contents(repo, path:, ref:)
      api.contents(repo, path: path, ref: ref)
    end

    def update_issue_comment(repo, comment_id, body)
      api.update_comment(repo, comment_id, body)
    end

    def create_issue_comment(repo, pr_number, body)
      api.add_comment(repo, pr_number, body)
    end

    private

    def build_api(token)
      require "octokit"

      options = { auto_paginate: true }
      options[:access_token] = token if token && !token.empty?
      Octokit::Client.new(**options)
    end
  end
end

