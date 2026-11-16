# frozen_string_literal: true
# rbs_inline: enabled

module Typegap
  # Type checks a project the way `steep check` does, from its Steepfile, and
  # hands each Ruby file's typing to a block. It reads Steep's own service
  # instead of re-implementing inference, so a finding means what Steep
  # inferred. That service is not a public API, so this file is the one place
  # that touches it.
  class Project
    attr_reader :root #: String

    # @rbs root: String
    def initialize(root) #: void
      @root = File.expand_path(root)
      steepfile = File.join(@root, "Steepfile")
      raise ArgumentError, "no Steepfile in #{@root}" unless File.file?(steepfile)

      @steep = Steep::Project.new(steepfile_path: Pathname(steepfile))
      Steep::Project::DSL.parse(@steep, File.read(steepfile), filename: steepfile)
      @service = Steep::Services::TypeCheckService.new(project: @steep)
      @loaded = false #: bool
    end

    # Each Ruby source file of a target, relative to the root, with its typing
    # and the RBS definition builder of its target. A file Steep could not
    # type (a syntax error) is skipped: `steep check` reports it.
    #
    # @rbs paths: Array[String]
    # @rbs &block: (String, untyped, untyped) -> void
    #: (Array[String]) { (String, untyped, untyped) -> void } -> void
    def each_typing(paths = [], &block)
      load
      wanted = paths.map { relative(_1) }
      source_paths.each do |path|
        next unless wanted.empty? || wanted.include?(path.to_s)

        target = @steep.target_for_source_path(path) or next
        @service.typecheck_source(path: path, target: target)
        typing = @service.source_files.fetch(path).typing or next
        block.call(path.to_s, typing, @service.signature_services.fetch(target.name).latest_builder)
      end
    end

    # The signature files under sig/, which hold this project's own types.
    # Stubs of other gems (sig-deps/ and the like) are not this project's to fix.
    #: () -> Array[String]
    def own_signature_paths
      load
      @changes.keys.map(&:to_s).select { _1.end_with?(".rbs") && _1.start_with?("sig/") }.sort
    end

    private

    #: () -> void
    def load
      return if @loaded

      @changes = {} #: Hash[Pathname, Array[untyped]]
      Dir.glob("**/*.{rb,rbs}", base: @root).each do |file|
        path = Pathname(file)
        next unless @steep.targets.any? { _1.possible_source_file?(path) || _1.possible_signature_file?(path) }

        @changes[path] = [Steep::Services::ContentChange.string(File.read(File.join(@root, file)))]
      end
      @service.update(changes: @changes)
      @loaded = true
    end

    #: () -> Array[Pathname]
    def source_paths = @changes.keys.select { _1.extname == ".rb" }.sort

    # @rbs path: String
    #: (String) -> String
    def relative(path)
      full = File.expand_path(path, Dir.pwd)
      full.start_with?("#{@root}/") ? full.delete_prefix("#{@root}/") : path
    end
  end
end
