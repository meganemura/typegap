# frozen_string_literal: true
# rbs_inline: enabled

module Typegap
  # The rules that read one Ruby file's typing. Each rule reports code that
  # the inferred types make unnecessary, impossible, or easy to misuse. In a
  # codebase typed with RBS, most of these are places where the type and the
  # code disagree: either the check is dead, or the type says too much.
  #
  # It reads Steep's typing and the RBS definitions; it does not infer types
  # of its own, and it never changes a file.
  class SourceCheck
    include TypeFacts

    # RBS core types these as never nil although they return nil (Hash#[] on
    # a missing key, Array#first on an empty array, Thread#join on a
    # timeout). Trusting them would report the very nil checks that keep the
    # code safe.
    NIL_HIDING_CALLS = %i[[] first last join dig find detect max min max_by min_by pop shift sample match fetch_values at].freeze #: Array[Symbol]

    BASE_TO_S = %w[::Object ::Kernel ::BasicObject].freeze #: Array[String]
    CONVERSIONS = { to_s: "::String", to_str: "::String", to_i: "::Integer", to_int: "::Integer", to_f: "::Float",
                    to_sym: "::Symbol", to_a: "::Array", to_ary: "::Array", to_h: "::Hash", to_hash: "::Hash" }.freeze #: Hash[Symbol, String]
    KERNEL_CONVERSIONS = { String: "::String", Integer: "::Integer", Float: "::Float", Array: "::Array", Hash: "::Hash" }.freeze #: Hash[Symbol, String]
    VALUE_CLASSES = %w[::String ::Array ::Hash ::Set].freeze #: Array[String]
    COLLECTIONS = %w[::Array ::Hash ::Set].freeze #: Array[String]
    BLOCKS = %i[block numblock itblock].freeze #: Array[Symbol]
    ITERATORS = %i[each each_with_index each_pair each_key each_value tap].freeze #: Array[Symbol]

    # @rbs path: String
    # @rbs typing: untyped
    # @rbs builder: untyped
    # @rbs rules: Array[String]
    def initialize(path, typing, builder, rules) #: void
      @path = path
      @typing = typing
      @builder = builder
      @rules = rules
      @found = [] #: Array[Finding]
      @ancestors = {} #: Hash[String, Array[String]?]
      @definitions = {} #: Hash[String, untyped]
      @deciders = {} #: Hash[untyped, Array[untyped]]
      @deciders.compare_by_identity
    end

    #: () -> Array[Finding]
    def findings
      walk(@typing.source.node, nil, [], false)
      steep_hidden
      @found
    end

    private

    # @rbs node_or_loc: untyped
    # @rbs rule: String
    # @rbs message: String
    #: (untyped, String, String) -> void
    def add(node_or_loc, rule, message)
      return unless @rules.include?(rule)

      loc = node_or_loc.is_a?(Parser::AST::Node) ? node_or_loc.loc.expression : node_or_loc
      @found << Finding.new(path: @path, line: loc.line, column: loc.column + 1, rule: rule, message: message)
    end

    # @rbs node: untyped
    #: (untyped) -> String
    def src(node) = node.loc.expression.source.lines.first.chomp

    # @rbs node: untyped
    # @rbs parent: untyped
    # @rbs nesting: Array[String]
    # @rbs singleton: bool
    #: (untyped, untyped, Array[String], bool) -> void
    def walk(node, parent, nesting, singleton)
      return unless node.is_a?(Parser::AST::Node)

      check(node, parent, nesting, singleton)
      case node.type
      when :class, :module
        inner = nesting + [node.children[0].loc.expression.source.delete_prefix("::")]
        node.children.drop(1).each { walk(_1, node, inner, false) }
      when :sclass
        node.children.drop(1).each { walk(_1, node, nesting, true) }
      else
        node.children.each { walk(_1, node, nesting, singleton) }
      end
    end

    # @rbs node: untyped
    # @rbs parent: untyped
    # @rbs nesting: Array[String]
    # @rbs singleton: bool
    #: (untyped, untyped, Array[String], bool) -> void
    def check(node, parent, nesting, singleton)
      case node.type
      when :csend then safe_navigation(node)
      when :send then send_rules(node, parent)
      when :if
        condition(node.children[0], :condition)
        node.children.drop(1).compact.each { @deciders[_1] = [node.children[0]] }
      when :while, :until then condition(node.children[0], :condition)
      when :and then condition(node.children[0], :and)
      when :or then or_rules(node)
      when :dstr, :dsym then interpolation(node)
      when :case
        case_rules(node)
        node.children.drop(1).compact.each { @deciders[_1] = [node.children[0], *_1.children] }
      when *BLOCKS then block_rules(node, parent)
      # rbs-inline reads `C = v #: T` to write the constant's type, so that
      # assertion is needed even when Steep infers the same type.
      when :assertion then assertion(node) unless parent&.type == :casgn
      when :splat then splat(node)
      when :def then def_rules(node, nesting, singleton)
      when :defs then def_rules(node, nesting, true)
      end
    end

    # --- types ---

    # @rbs node: untyped
    #: (untyped) -> untyped
    def type_of(node)
      return nil if node.nil?
      return nil if node.type == :send && NIL_HIDING_CALLS.include?(node.children[1])
      # An instance variable read before it is set is nil whatever its annotation says.
      return nil if node.type == :ivar
      # `x = h[k]` is as nil as `h[k]`.
      return type_of(node.children.last) if node.type == :lvasgn && node.children.size == 2
      return type_of(node.children[0]) if node.type == :begin && node.children.size == 1

      raw_type(node)
    end

    # @rbs node: untyped
    #: (untyped) -> untyped
    def raw_type(node)
      @typing.type_of(node: node)
    rescue StandardError
      nil
    end

    # @rbs name: String
    #: (String) -> Array[String]?
    def ancestors(name)
      return @ancestors[name] if @ancestors.key?(name)

      @ancestors[name] = begin
        @builder.ancestor_builder.instance_ancestors(RBS::TypeName.parse(name)).ancestors.map { _1.name.to_s }
      rescue StandardError
        nil
      end
    end

    # @rbs name: String
    #: (String) -> untyped
    def instance_definition(name)
      return @definitions[name] if @definitions.key?(name)

      @definitions[name] = begin
        @builder.build_instance(RBS::TypeName.parse(name))
      rescue StandardError
        nil
      end
    end

    # @rbs name: String
    #: (String) -> untyped
    def singleton_definition(name)
      @builder.build_singleton(RBS::TypeName.parse(name))
    rescue StandardError
      nil
    end

    # @rbs name: String
    #: (String) -> bool
    def class_entry?(name)
      @builder.env.class_decls[RBS::TypeName.parse(name)].is_a?(RBS::Environment::ClassEntry)
    rescue StandardError
      false
    end

    # @rbs type_name: String
    # @rbs method: Symbol
    #: (String, Symbol) -> String?
    def method_owner(type_name, method)
      instance_definition(type_name)&.methods&.[](method)&.defined_in&.to_s
    end

    # @rbs node: untyped
    #: (untyped) -> String?
    def const_name(node)
      type = raw_type(node)
      type.is_a?(Steep::AST::Types::Name::Singleton) ? type.name.to_s : nil
    end

    # --- nil and conditions ---

    # @rbs node: untyped
    #: (untyped) -> void
    def safe_navigation(node)
      receiver = node.children[0]
      type = type_of(receiver)
      return unless never_nil?(type)

      add(node, "UnnecessarySafeNavigation", "`#{src(receiver)}` is `#{type}`, never nil, so `&.` is not needed")
    end

    # @rbs node: untyped
    # @rbs parent: untyped
    #: (untyped, untyped) -> void
    def send_rules(node, parent)
      receiver, name, *args = node.children
      nil_check(node, receiver, name, args)
      type_check(node, receiver, name, args)
      boolean_compare(node, receiver, name, args)
      conversion(node, receiver, name, args) unless parent && BLOCKS.include?(parent.type) && parent.children[0] == node
      literal_comparison(node, receiver, name, args)
      unused_result(node, parent, receiver, name)
      void_used(node, parent)
      untyped_call(node, receiver)
      sort_comparable(node, parent, receiver, name, args)
    end

    # @rbs node: untyped
    # @rbs receiver: untyped
    # @rbs name: Symbol
    # @rbs args: Array[untyped]
    #: (untyped, untyped, Symbol, Array[untyped]) -> void
    def nil_check(node, receiver, name, args)
      return unless receiver
      return unless (name == :nil? && args.empty?) || (%i[== !=].include?(name) && args[0]&.type == :nil)

      type = type_of(receiver)
      return unless never_nil?(type)

      add(node, "UnnecessaryNilCheck", "`#{src(receiver)}` is `#{type}`, never nil, so this check is always the same")
    end

    # @rbs cond: untyped
    # @rbs kind: Symbol
    #: (untyped, Symbol) -> void
    def condition(cond, kind)
      return if cond.nil? || %i[true false].include?(cond.type)
      # UnnecessaryNilCheck and UnnecessarySafeNavigation report these.
      return if (cond.type == :send && cond.children[1] == :nil?) || cond.type == :csend

      type = type_of(cond)
      return unless never_falsy?(type)
      return if members(type).all? { _1.is_a?(Steep::AST::Types::Literal) && _1.value == true }

      what = kind == :and ? "the left side of `&&`" : "this condition"
      add(cond, "AlwaysTruthyCondition", "`#{src(cond)}` is `#{type}`, never nil or false, so #{what} is always true (0 and \"\" are true in Ruby)")
    end

    # @rbs node: untyped
    #: (untyped) -> void
    def or_rules(node)
      left, right = node.children
      type = type_of(left)
      return unless type

      if never_falsy?(type)
        add(node, "UnnecessaryDefault", "`#{src(left)}` is `#{type}`, never nil or false, so the right side of `||` is never used")
      elsif known?(type) && members(type).any? { can_be_false?(_1) } && members(type).any? { nil_type?(_1) } && !boolean_logic?(right)
        add(node, "OrReplacesFalse", "`#{src(left)}` is `#{type}`; `||` replaces false as well as nil. Use `x.nil? ? default : x` to replace only nil")
      end
    end

    # `a&.x? || b&.y?` is logic, not a default: false there is meant to fall
    # through. `flag || true` is a default, and the very bug this rule is for.
    #
    # @rbs right: untyped
    #: (untyped) -> bool
    def boolean_logic?(right)
      return false if %i[true false].include?(right.type)

      type = type_of(right)
      type.nil? || !known?(type) || members(type).all? { bool_type?(_1) || nil_type?(_1) }
    end

    # @rbs node: untyped
    # @rbs receiver: untyped
    # @rbs name: Symbol
    # @rbs args: Array[untyped]
    #: (untyped, untyped, Symbol, Array[untyped]) -> void
    def type_check(node, receiver, name, args)
      if %i[is_a? kind_of?].include?(name) && receiver && args.size == 1
        class_check(node, receiver, args[0])
      elsif name == :=== && receiver&.type == :const && args.size == 1
        class_check(node, args[0], receiver)
      elsif name == :respond_to? && receiver && args.size == 1 && args[0].type == :sym
        respond_check(node, receiver, args[0].children[0])
      end
    end

    # @rbs node: untyped
    # @rbs value: untyped
    # @rbs const: untyped
    #: (untyped, untyped, untyped) -> void
    def class_check(node, value, const)
      klass = const_name(const) or return
      type = type_of(value)
      return unless type && known?(type) && !type.is_a?(Steep::AST::Types::Intersection)

      names = members(type).map { nil_type?(_1) ? "::NilClass" : instance_name(_1) }
      return if names.any?(&:nil?)

      lists = names.map { ancestors(_1.to_s) }
      return if lists.any?(&:nil?)

      if lists.all? { _1&.include?(klass) }
        add(node, "UnnecessaryTypeCheck", "`#{src(value)}` is `#{type}`, always a `#{klass}`, so this check is always true")
      elsif disjoint?(klass, names, lists)
        add(node, "UnnecessaryTypeCheck", "`#{src(value)}` is `#{type}`, never a `#{klass}`, so this check is always false")
      end
    end

    # Only classes can be disjoint: any object can include a module.
    #
    # @rbs klass: String
    # @rbs names: Array[String?]
    # @rbs lists: Array[Array[String]?]
    #: (String, Array[String?], Array[Array[String]?]) -> bool
    def disjoint?(klass, names, lists)
      return false unless class_entry?(klass) && names.all? { class_entry?(_1.to_s) }

      names.zip(lists).none? { |name, list| list&.include?(klass) || ancestors(klass)&.include?(name) }
    end

    # @rbs node: untyped
    # @rbs receiver: untyped
    # @rbs method: Symbol
    #: (untyped, untyped, Symbol) -> void
    def respond_check(node, receiver, method)
      type = type_of(receiver)
      name = instance_name(type) or return
      meth = instance_definition(name)&.methods&.[](method) or return
      return unless meth.accessibility == :public

      add(node, "UnnecessaryTypeCheck", "`#{src(receiver)}` is `#{type}`, which has a public `#{method}`, so `respond_to?` is always true")
    end

    # @rbs node: untyped
    # @rbs receiver: untyped
    # @rbs name: Symbol
    # @rbs args: Array[untyped]
    #: (untyped, untyped, Symbol, Array[untyped]) -> void
    def boolean_compare(node, receiver, name, args)
      return unless receiver && %i[== !=].include?(name) && %i[true false].include?(args[0]&.type)

      type = type_of(receiver)
      return unless type && known?(type) && members(type).all? { bool_type?(_1) }

      add(node, "UnnecessaryBooleanCompare", "`#{src(receiver)}` is `#{type}`, so compare it without `#{name} #{args[0].type}`")
    end

    # @rbs node: untyped
    # @rbs receiver: untyped
    # @rbs name: Symbol
    # @rbs args: Array[untyped]
    #: (untyped, untyped, Symbol, Array[untyped]) -> void
    def conversion(node, receiver, name, args)
      if receiver && args.empty? && (want = CONVERSIONS[name])
        type = type_of(receiver)
        return unless instance_name(type) == want

        add(node, "UnnecessaryConversion", "`#{src(receiver)}` is already `#{type}`, so `.#{name}` returns the same value")
      elsif receiver.nil? && args.size == 1 && (want = KERNEL_CONVERSIONS[name])
        type = type_of(args[0])
        return unless instance_name(type) == want

        add(node, "UnnecessaryConversion", "`#{src(args[0])}` is already `#{type}`, so `#{name}(...)` returns the same value")
      end
    end

    # [readable, value] for a literal node; nil for anything else.
    #
    # @rbs node: untyped
    #: (untyped) -> [bool, untyped]
    def literal_value(node)
      case node.type
      when :sym, :str, :int then [true, node.children[0]]
      when :nil then [true, nil]
      else [false, nil]
      end
    end

    # @rbs node: untyped
    # @rbs receiver: untyped
    # @rbs name: Symbol
    # @rbs args: Array[untyped]
    #: (untyped, untyped, Symbol, Array[untyped]) -> void
    def literal_comparison(node, receiver, name, args)
      return unless receiver && %i[== !=].include?(name) && args.size == 1

      readable, value = literal_value(args[0])
      return unless readable && !value.nil?

      type = type_of(receiver)
      return unless type && literal_union?(type) && !includes_literal?(type, value)

      add(node, "ImpossibleLiteralComparison",
          "`#{src(receiver)}` is `#{type}`, never `#{value.inspect}`, so `#{name}` is always #{name == :== ? "false" : "true"}")
    end

    # --- results ---

    # @rbs node: untyped
    # @rbs parent: untyped
    #: (untyped, untyped) -> bool
    def statement?(node, parent)
      !parent.nil? && %i[begin kwbegin].include?(parent.type) && !parent.children.last.equal?(node)
    end

    # @rbs node: untyped
    # @rbs parent: untyped
    # @rbs receiver: untyped
    # @rbs name: Symbol
    #: (untyped, untyped, untyped, Symbol) -> void
    def unused_result(node, parent, receiver, name)
      return unless statement?(node, parent) && receiver
      return if name.end_with?("!", "?", "=") || name == :freeze

      klass = instance_name(type_of(receiver))
      return unless klass && VALUE_CLASSES.include?(klass) && bang?(klass, name)

      add(node, "UnusedResult", "`#{src(node)}` returns a new #{klass.delete_prefix("::")} and its result is not used; `#{name}!` changes the receiver")
    end

    # @rbs klass: String
    # @rbs name: Symbol
    #: (String, Symbol) -> bool
    def bang?(klass, name) = instance_definition(klass)&.methods&.key?(:"#{name}!") || false

    # @rbs node: untyped
    # @rbs parent: untyped
    #: (untyped, untyped) -> void
    def void_used(node, parent)
      return unless parent && raw_type(node).is_a?(Steep::AST::Types::Void)

      # Not `return`: `return log(...)` is an early exit, not a use.
      used = case parent.type
             when :lvasgn, :ivasgn, :gvasgn, :cvasgn, :casgn, :op_asgn, :array, :pair, :dstr then true
             when :send, :csend then !parent.children[0].equal?(node)
             when :if then parent.children[0].equal?(node)
             else false
             end
      add(node, "VoidValueUsed", "`#{src(node)}` returns void, so its value means nothing here") if used
    end

    # @rbs node: untyped
    # @rbs receiver: untyped
    #: (untyped, untyped) -> void
    def untyped_call(node, receiver)
      return unless receiver && raw_type(receiver).is_a?(Steep::AST::Types::Any)

      add(node, "UntypedCall", "`#{src(receiver)}` is untyped, so Steep does not check `.#{node.children[1]}`")
    end

    # @rbs node: untyped
    # @rbs parent: untyped
    # @rbs receiver: untyped
    # @rbs name: Symbol
    # @rbs args: Array[untyped]
    #: (untyped, untyped, untyped, Symbol, Array[untyped]) -> void
    def sort_comparable(node, parent, receiver, name, args)
      return unless receiver && %i[sort sort! max min minmax].include?(name) && args.empty?
      return if parent && BLOCKS.include?(parent.type) && parent.children[0].equal?(node)

      type = type_of(receiver)
      return unless type.is_a?(Steep::AST::Types::Name::Instance) && %w[::Array ::Set].include?(type.name.to_s)

      element = type.args[0]
      return unless element && known?(element)

      kinds = members(element).map { class_name(_1) }
      return if kinds.any?(&:nil?)

      kinds.uniq!
      if kinds.size > 1 && !(kinds - %w[::Integer ::Float ::Rational]).empty?
        add(node, "SortWithoutComparable",
            "the elements are `#{element}`; `#{name}` raises ArgumentError when it compares two of these classes. Pass a block or `#{name}_by`")
      elsif kinds.size == 1 && BASE_TO_S.include?(method_owner(kinds[0].to_s, :<=>))
        add(node, "SortWithoutComparable", "`#{kinds[0]}` has only Object#<=>, so `#{name}` raises ArgumentError. Pass a block or `#{name}_by`")
      end
    end

    # @rbs node: untyped
    #: (untyped) -> void
    def interpolation(node)
      node.children.select { _1.type == :begin }.each do |part|
        expr = part.children[0] or next
        # `"#{x if c}"` means "" on purpose; `$1` is checked by the match before it.
        next if %i[if nth_ref].include?(expr.type)

        type = type_of(expr)
        next unless type && known?(type)

        interpolated(node, part, expr, type)
      end
    end

    # @rbs node: untyped
    # @rbs part: untyped
    # @rbs expr: untyped
    # @rbs type: untyped
    #: (untyped, untyped, untyped, untyped) -> void
    def interpolated(node, part, expr, type)
      name = instance_name(type)
      if node.type == :dstr && node.children.size == 1 && name == "::String"
        add(node, "UnnecessaryConversion", "`#{src(expr)}` is already `#{type}`, so `\"\#{...}\"` returns the same value")
      elsif nilable?(type)
        add(part, "RestrictInterpolation", "`#{src(expr)}` is `#{type}`; nil becomes an empty string here")
      elsif name && COLLECTIONS.include?(name)
        add(part, "RestrictInterpolation", "`#{src(expr)}` is `#{type}`; it prints in inspect form (`[...]`, `{...}`)")
      elsif name && BASE_TO_S.include?(method_owner(name, :to_s)) && class_entry?(name)
        add(part, "RestrictInterpolation", "`#{src(expr)}` is `#{type}`, which has no `to_s` of its own, so it prints as `#<#{name.delete_prefix("::")}>`")
      end
    end

    # --- case ---

    # @rbs node: untyped
    #: (untyped) -> void
    def case_rules(node)
      subject, *whens, else_body = node.children
      return unless subject

      type = type_of(subject)
      return unless type && known?(type) && type.is_a?(Steep::AST::Types::Union)

      conds = whens.flat_map { _1.children[0..-2] }
      return if conds.any? { _1.type == :splat }

      impossible_whens(subject, type, conds) if literal_union?(type)
      exhaustive(node, subject, type, conds) unless else_body
    end

    # @rbs subject: untyped
    # @rbs type: untyped
    # @rbs conds: Array[untyped]
    #: (untyped, untyped, Array[untyped]) -> void
    def impossible_whens(subject, type, conds)
      conds.each do |cond|
        readable, value = literal_value(cond)
        next unless readable && !value.nil? && !includes_literal?(type, value)

        add(cond, "ImpossibleLiteralComparison", "`#{src(subject)}` is `#{type}`, never `#{value.inspect}`, so this `when` never matches")
      end
    end

    # @rbs node: untyped
    # @rbs subject: untyped
    # @rbs type: untyped
    # @rbs conds: Array[untyped]
    #: (untyped, untyped, untyped, Array[untyped]) -> void
    def exhaustive(node, subject, type, conds)
      by_class = conds.any? { _1.type == :const }
      # nil falling through to the implicit nil of `case` is the Ruby idiom, not
      # a gap. A String member against `when "a"` is open-ended: only a
      # class-based case can miss a class.
      missing = members(type).reject do |member|
        nil_type?(member) || (member.is_a?(Steep::AST::Types::Name::Instance) && !by_class) || covered?(member, conds)
      end
      return if missing.empty? || missing.size == members(type).size

      add(node.loc.keyword, "CaseExhaustiveness",
          "`#{src(subject)}` is `#{type}`, but no `when` handles #{missing.map { "`#{_1}`" }.join(", ")} and there is no `else`")
    end

    # @rbs member: untyped
    # @rbs conds: Array[untyped]
    #: (untyped, Array[untyped]) -> bool
    def covered?(member, conds)
      conds.any? do |cond|
        readable, value = literal_value(cond)
        if readable
          (value.nil? && nil_type?(member)) || (member.is_a?(Steep::AST::Types::Literal) && member.value == value)
        elsif cond.type == :const && (klass = const_name(cond))
          name = class_name(member)
          # A `when` on a subclass handles part of the member: stay silent rather than guess.
          !name.nil? && (ancestors(name)&.include?(klass) || ancestors(klass)&.include?(name) || false)
        else
          true # a pattern this rule cannot read: assume it covers
        end
      end
    end

    # --- blocks, assertions, splats ---

    # @rbs node: untyped
    # @rbs parent: untyped
    #: (untyped, untyped) -> void
    def block_rules(node, parent)
      send = node.children[0]
      return unless send.type == :send

      receiver, name = send.children
      klass = receiver ? instance_name(type_of(receiver)) : nil
      return unless klass

      prefer_find(node, parent, name, klass)
      return unless statement?(node, parent) && VALUE_CLASSES.include?(klass)
      return if name.end_with?("!", "?") || ITERATORS.include?(name) || !bang?(klass, name)

      add(node, "UnusedResult", "`#{src(send)} { ... }` returns a new #{klass.delete_prefix("::")} and its result is not used; `#{name}!` changes the receiver")
    end

    # @rbs node: untyped
    # @rbs parent: untyped
    # @rbs name: Symbol
    # @rbs klass: String
    #: (untyped, untyped, Symbol, String) -> void
    def prefer_find(node, parent, name, klass)
      return unless parent&.type == :send && parent.children[0].equal?(node) && parent.children[1] == :first && parent.children.size == 2
      return unless %i[select filter].include?(name) && COLLECTIONS.include?(klass)

      add(parent, "PreferFind", "`#{name} { ... }.first` on #{klass.delete_prefix("::")} builds a whole list to take one; use `find { ... }`")
    end

    # @rbs node: untyped
    #: (untyped) -> void
    def assertion(node)
      inner = node.children[0]
      inner_type = raw_type(inner)
      asserted = raw_type(node)
      return unless inner_type && asserted

      # Steep types these from the assertion itself (a literal, an empty or
      # literal collection, nil, a generic `.new`), so the assertion is what
      # gave them their type: `false #: bool` widens what would be `false`.
      core = inner.type == :send && inner.children[1] == :freeze ? inner.children[0] : inner
      return if hint_shaped?(core) || inner_type.to_s.include?("bot")

      if inner_type == asserted && known?(asserted)
        add(node, "UnnecessaryTypeAssertion", "`#{src(inner)}` is already `#{asserted}`, so the `#:` assertion can go")
      elsif known?(inner_type) && members(inner_type).any? { nil_type?(_1) } && never_nil?(asserted)
        add(node, "NilDroppingAssertion",
            "`#{src(inner)}` is `#{inner_type}`; the assertion `#{asserted}` drops nil without a check. Raise or handle nil instead")
      end
    end

    # @rbs node: untyped
    #: (untyped) -> bool
    def hint_shaped?(node)
      return false unless node.is_a?(Parser::AST::Node)
      return true if %i[array hash nil true false int float str sym lambda block numblock].include?(node.type) || (node.type == :send && node.children[1] == :new)
      return node.children.drop(1).any? { hint_shaped?(_1) } if node.type == :if
      return node.children.any? { hint_shaped?(_1) } if %i[begin or and].include?(node.type)

      false
    end

    # @rbs node: untyped
    #: (untyped) -> void
    def splat(node)
      value = node.children[0] or return
      type = type_of(value)
      return unless instance_name(type) == "::Hash"

      add(node, "MisusedSplat", "`#{src(value)}` is `#{type}`; `*` splits it into [key, value] pairs. Use `**` for keywords")
    end

    # --- method definitions ---

    # @rbs node: untyped
    # @rbs nesting: Array[String]
    # @rbs singleton: bool
    #: (untyped, Array[String], bool) -> void
    def def_rules(node, nesting, singleton)
      return if nesting.empty?

      name = node.type == :defs ? node.children[1] : node.children[0]
      type_name = "::#{nesting.join("::")}"
      definition = singleton ? singleton_definition(type_name) : instance_definition(type_name)
      returns = definition&.methods&.[](name)&.method_types&.map { _1.type.return_type } || []
      return if returns.empty?

      if name.end_with?("?") && returns.none? { boolish?(_1) }
        add(node.loc.name, "PredicateReturnType", "`#{name}` ends with `?` but returns `#{returns.join(" | ")}`; return bool or rename it")
      end
      body = node.children.last
      last = body&.type == :begin ? body.children.last : body
      return unless last&.type == :self && returns.all? { _1.is_a?(RBS::Types::ClassInstance) && _1.name.to_s == type_name }

      add(node.loc.name, "PreferReturnSelfType", "`#{name}` returns `self` but its type says `#{type_name.delete_prefix("::")}`; `-> self` keeps the subclass type")
    end

    # @rbs type: untyped
    #: (untyped) -> bool
    def boolish?(type)
      case type
      when RBS::Types::Bases::Bool, RBS::Types::Bases::Any, RBS::Types::Bases::Top then true
      when RBS::Types::Literal then [true, false].include?(type.literal)
      when RBS::Types::Alias then type.name.to_s.delete_prefix("::") == "boolish"
      when RBS::Types::Optional then boolish?(type.type)
      when RBS::Types::Union then type.types.all? { boolish?(_1) || _1.is_a?(RBS::Types::Bases::Nil) }
      else false
      end
    end

    # Steep finds these itself, but its default diagnostic levels hide them as hints.
    #: () -> void
    def steep_hidden
      @typing.errors.each do |error|
        case error
        when Steep::Diagnostic::Ruby::UnreachableBranch, Steep::Diagnostic::Ruby::UnreachableValueBranch
          next if @deciders[error.node]&.any? { reads_hidden_nil?(_1) }

          add(error.location, "UnreachableBranch", error.header_line)
        when Steep::Diagnostic::Ruby::DeprecatedReference
          add(error.location, "DeprecatedReference", error.header_line)
        end
      end
    end

    # Steep decides a branch is unreachable from the same types the rules
    # above distrust: `h[k].nil?` is never true to it. Such a branch is kept.
    # @rbs node: untyped
    #: (untyped) -> bool
    def reads_hidden_nil?(node)
      return false unless node.is_a?(Parser::AST::Node)
      return true if node.type == :ivar
      return true if %i[send csend].include?(node.type) && NIL_HIDING_CALLS.include?(node.children[1])

      node.children.any? { reads_hidden_nil?(_1) }
    end
  end
end
