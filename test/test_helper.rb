# frozen_string_literal: true

require "minitest/autorun"
require "typegap"

module Fixtures
  DIR = File.expand_path("fixtures", __dir__) #: String

  # Steep takes a few seconds to load a project, so each fixture runs once.
  @runs = {}

  def self.findings(name, rules: Typegap::Rules::NAMES)
    @runs[[name, rules]] ||= Typegap.run(root: File.join(DIR, name), rules: rules)
  end
end
