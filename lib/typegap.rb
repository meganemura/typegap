# frozen_string_literal: true
# rbs_inline: enabled

require "json"
require "optparse"
require "steep"
require_relative "typegap/version"
require_relative "typegap/finding"
require_relative "typegap/rules"
require_relative "typegap/type_facts"
require_relative "typegap/project"
require_relative "typegap/source_check"
require_relative "typegap/signature_check"
require_relative "typegap/cli"

# typegap reports where a Ruby project's RBS types and its code disagree, on
# the typing Steep infers. It ports the type-aware rules of typescript-eslint.
module Typegap
  # Every finding in a project, sorted by place. `paths` limits the Ruby files
  # read; signature files are read only when no path is given.
  #
  # @rbs root: String
  # @rbs paths: Array[String]
  # @rbs rules: Array[String]
  #: (root: String, ?paths: Array[String], ?rules: Array[String]) -> Array[Finding]
  def self.run(root:, paths: [], rules: Rules.select(only: nil, except: []))
    project = Project.new(root)
    found = [] #: Array[Finding]
    project.each_typing(paths) do |path, typing, builder|
      found.concat(SourceCheck.new(path, typing, builder, rules).findings)
    end
    if paths.empty?
      project.own_signature_paths.each do |path|
        found.concat(SignatureCheck.new(path, File.read(File.join(project.root, path)), rules).findings)
      end
    end
    found.sort_by(&:sort_key)
  end
end
