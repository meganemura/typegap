# frozen_string_literal: true

require_relative "lib/typegap/version"

Gem::Specification.new do |spec|
  spec.name = "typegap"
  spec.version = Typegap::VERSION
  spec.authors = ["meganemura"]
  spec.summary = "Find where a Ruby project's RBS types and its code disagree, with typescript-eslint's type-aware rules on Steep."
  spec.homepage = "https://github.com/meganemura/typegap"
  spec.license = "MIT"
  spec.metadata = {
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "bug_tracker_uri" => "#{spec.homepage}/issues",
    "rubygems_mfa_required" => "true"
  }
  spec.required_ruby_version = ">= 3.3.0"
  spec.files = Dir["lib/**/*.rb", "sig/**/*.rbs", "exe/*", "README.md", "README.ja.md", "LICENSE", "CHANGELOG.md"]
  spec.bindir = "exe"
  spec.executables = ["typegap"]
  # typegap reads Steep's type check service, which is not a public API, so
  # it allows only the minor version it is tested with.
  spec.add_dependency "steep", ">= 2.1.0", "< 2.2"
end
