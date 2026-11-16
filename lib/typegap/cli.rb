# frozen_string_literal: true
# rbs_inline: enabled

module Typegap
  # The `typegap` command. It prints one finding per line, or one JSON object
  # per line with `--json`, and exits 1 when there is a finding, so a CI job
  # can run it as is.
  class CLI
    USAGE = "Usage: typegap [--json] [--only RULE,...] [--except RULE,...] [--root DIR] [PATH...]" #: String

    # @rbs out: IO
    # @rbs err: IO
    def initialize(out: $stdout, err: $stderr) #: void
      @out = out
      @err = err
    end

    # 0 with no finding, 1 with findings, 2 when the command cannot run.
    # @rbs argv: Array[String]
    #: (Array[String]) -> Integer
    def run(argv)
      options = parse(argv.dup)
      return 0 if options[:done]

      rules = Rules.select(only: options[:only], except: options[:except])
      findings = Typegap.run(root: options[:root], paths: options[:paths], rules: rules)
      report(findings, json: options[:json])
      findings.empty? ? 0 : 1
    rescue OptionParser::ParseError, ArgumentError => e
      @err.puts "typegap: #{e.message}"
      @err.puts USAGE
      2
    end

    private

    # @rbs argv: Array[String]
    #: (Array[String]) -> Hash[Symbol, untyped]
    def parse(argv)
      options = { json: false, only: nil, except: [], root: Dir.pwd, done: false } #: Hash[Symbol, untyped]
      parser = OptionParser.new(USAGE)
      parser.on("--json", "Print one JSON object per finding") { options[:json] = true }
      parser.on("--only RULES", Array, "Run only these rules (comma separated)") { options[:only] = _1 }
      parser.on("--except RULES", Array, "Skip these rules (comma separated)") { options[:except] = _1 }
      parser.on("--root DIR", "The directory that holds the Steepfile (default: .)") { options[:root] = _1 }
      parser.on("--rules", "List the rules and exit") do
        Rules::ALL.each { @out.puts "#{_1.name}#{_1.default ? "" : " (off by default)"}: follows #{_1.follows}" }
        options[:done] = true
      end
      parser.on("--version", "Print the version and exit") do
        @out.puts VERSION
        options[:done] = true
      end
      parser.on("-h", "--help", "Print this help and exit") do
        @out.puts parser.help
        options[:done] = true
      end
      options[:paths] = parser.parse(argv)
      options
    end

    # @rbs findings: Array[Finding]
    # @rbs json: bool
    #: (Array[Finding], json: bool) -> void
    def report(findings, json:)
      findings.each { @out.puts(json ? JSON.generate(_1.to_h) : _1.to_s) }
      @err.puts "#{findings.size} finding#{findings.size == 1 ? "" : "s"}" unless json
    end
  end
end
