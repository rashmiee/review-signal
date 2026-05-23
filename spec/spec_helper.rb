# frozen_string_literal: true

require "base64"

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "review_signal"

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end
end
