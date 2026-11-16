# frozen_string_literal: true
# rbs_inline: enabled

module Typegap
  # The rules that read one signature file, as written or as rbs-inline
  # writes it. They report a type that says less than it seems to: a union
  # that `untyped` swallows, a type parameter that ties nothing together, a
  # getter and a setter that disagree.
  #
  # It reads the file's declarations only. It does not resolve names, so it
  # needs no environment.
  class SignatureCheck
    # @rbs path: String
    # @rbs text: String
    # @rbs rules: Array[String]
    def initialize(path, text, rules) #: void
      @path = path
      @text = text
      @rules = rules
      @found = [] #: Array[Finding]
    end

    # A file RBS cannot parse has no findings: `steep check` reports it.
    #: () -> Array[Finding]
    def findings
      _, _, decls = RBS::Parser.parse_signature(@text)
      decls.each { decl(_1) }
      @found
    rescue RBS::ParsingError
      []
    end

    private

    # @rbs loc: untyped
    # @rbs rule: String
    # @rbs message: String
    #: (untyped, String, String) -> void
    def add(loc, rule, message)
      return unless loc && @rules.include?(rule)

      @found << Finding.new(path: @path, line: loc.start_line, column: loc.start_column + 1, rule: rule, message: message)
    end

    # @rbs decl: untyped
    #: (untyped) -> void
    def decl(decl)
      case decl
      when RBS::AST::Declarations::Class, RBS::AST::Declarations::Module, RBS::AST::Declarations::Interface
        decl.super_class&.args&.each { each_type(_1) } if decl.is_a?(RBS::AST::Declarations::Class)
        decl.members.each { member(_1) }
        getter_setter(decl)
        decl.members.each { decl(_1) if _1.is_a?(RBS::AST::Declarations::Base) }
      when RBS::AST::Declarations::TypeAlias, RBS::AST::Declarations::Constant, RBS::AST::Declarations::Global
        each_type(decl.type)
      end
    end

    # @rbs member: untyped
    #: (untyped) -> void
    def member(member)
      case member
      when RBS::AST::Members::MethodDefinition
        member.overloads.each do |overload|
          method_type = overload.method_type
          # MethodType#each_type walks the block's types too.
          method_type.each_type { each_type(_1) }
          type_params(member, method_type)
        end
      when RBS::AST::Members::Attribute, RBS::AST::Members::InstanceVariable,
           RBS::AST::Members::ClassInstanceVariable, RBS::AST::Members::ClassVariable
        each_type(member.type)
      when RBS::AST::Members::Include, RBS::AST::Members::Extend, RBS::AST::Members::Prepend
        member.args.each { each_type(_1) }
      end
    end

    # @rbs type: untyped
    #: (untyped) -> void
    def each_type(type)
      redundant(type)
      type.each_type { each_type(_1) } if type.respond_to?(:each_type)
    end

    # @rbs type: untyped
    #: (untyped) -> void
    def redundant(type)
      case type
      when RBS::Types::Union
        types = type.types
        if types.any? { _1.is_a?(RBS::Types::Bases::Any) }
          add(type.location, "RedundantTypeConstituents", "`#{type}` contains `untyped`, so the whole union is untyped")
        end
        dups = types.map(&:to_s).tally.select { _2 > 1 }.keys
        add(type.location, "RedundantTypeConstituents", "`#{type}` lists #{dups.join(", ")} twice") if dups.any?
        if types.any? { _1.is_a?(RBS::Types::Bases::Bool) } &&
           types.any? { _1.is_a?(RBS::Types::Literal) && [true, false].include?(_1.literal) }
          add(type.location, "RedundantTypeConstituents", "`#{type}` has `bool` and a true or false literal")
        end
      when RBS::Types::Optional
        add(type.location, "RedundantTypeConstituents", "`#{type}`: the inner type already includes nil, so `?` adds nothing") if nil_inside?(type.type)
      end
    end

    # @rbs type: untyped
    #: (untyped) -> bool
    def nil_inside?(type)
      case type
      when RBS::Types::Optional, RBS::Types::Bases::Any, RBS::Types::Bases::Nil then true
      when RBS::Types::Union then type.types.any? { _1.is_a?(RBS::Types::Bases::Nil) || _1.is_a?(RBS::Types::Optional) }
      else false
      end
    end

    # A type parameter used once relates nothing: `[T] (T) -> void` takes
    # anything, as `(untyped) -> void` or `(top) -> void` does.
    # @rbs member: untyped
    # @rbs method_type: untyped
    #: (untyped, untyped) -> void
    def type_params(member, method_type)
      method_type.type_params.each do |param|
        uses = 0
        count = lambda do |t|
          uses += 1 if t.is_a?(RBS::Types::Variable) && t.name == param.name
          t.each_type { count.(_1) } if t.respond_to?(:each_type)
        end
        method_type.each_type { count.(_1) }
        method_type.type_params.each { count.(_1.upper_bound) if _1.upper_bound }
        next if uses > 1

        add(member.location, "UnnecessaryTypeParameter",
            "`#{member.name}` declares `[#{param.name}]` but uses it #{uses} time(s); it ties nothing together, so `untyped` or `top` says the same")
      end
    end

    # @rbs decl: untyped
    #: (untyped) -> void
    def getter_setter(decl)
      getters = {} #: Hash[Symbol, String]
      setters = {} #: Hash[Symbol, [String, untyped]]
      decl.members.each do |m|
        case m
        when RBS::AST::Members::AttrReader then getters[m.name] = m.type.to_s
        when RBS::AST::Members::AttrWriter then setters[m.name] = [m.type.to_s, m]
        when RBS::AST::Members::AttrAccessor then next
        when RBS::AST::Members::MethodDefinition
          next unless m.kind == :instance && m.overloads.size == 1

          fn = m.overloads[0].method_type.type
          next unless fn.is_a?(RBS::Types::Function)

          if m.name.end_with?("=") && fn.required_positionals.size == 1
            setters[m.name.to_s.chomp("=").to_sym] = [fn.required_positionals[0].type.to_s, m]
          elsif fn.required_positionals.empty? && fn.optional_positionals.empty?
            getters[m.name] = fn.return_type.to_s
          end
        end
      end
      setters.each do |name, (type, m)|
        getter = getters[name] or next
        next if getter == type

        add(m.location, "GetterSetterMismatch", "`#{name}` returns `#{getter}` but `#{name}=` takes `#{type}`")
      end
    end
  end
end
