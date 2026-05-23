# frozen_string_literal: true

module ReviewSignal
  PullRequestContext = Struct.new(
    :repo,
    :number,
    :title,
    :base_sha,
    :head_sha,
    :files,
    keyword_init: true
  )
end

