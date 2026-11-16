# frozen_string_literal: true
# rbs_inline: enabled

module Typegap
  # What a Steep type says about nil, false, and classes. Every predicate
  # answers only for a type Steep knows completely: untyped, a type variable,
  # self, or an alias Steep did not expand says nothing, so a rule built on
  # these stays silent there instead of guessing.
  module TypeFacts

    module_function

    # @rbs type: untyped
    #: (untyped) -> Array[untyped]
    def members(type) = type.is_a?(Steep::AST::Types::Union) ? type.types : [type]

    # @rbs type: untyped
    #: (untyped) -> String?
    def instance_name(type) = type.is_a?(Steep::AST::Types::Name::Instance) ? type.name.to_s : nil

    # The class name of a member, with nil as NilClass and a literal as its class.
    # @rbs type: untyped
    #: (untyped) -> String?
    def class_name(type)
      return "::NilClass" if nil_type?(type)
      return "::#{type.value.class}" if type.is_a?(Steep::AST::Types::Literal)

      instance_name(type)
    end

    # @rbs type: untyped
    #: (untyped) -> bool
    def nil_type?(type) = type.is_a?(Steep::AST::Types::Nil) || instance_name(type) == "::NilClass"

    # @rbs type: untyped
    #: (untyped) -> bool
    def bool_type?(type)
      type.is_a?(Steep::AST::Types::Boolean) || type.is_a?(Steep::AST::Types::Logic::Base) ||
        (type.is_a?(Steep::AST::Types::Literal) && [true, false].include?(type.value)) ||
        %w[::TrueClass ::FalseClass].include?(instance_name(type))
    end

    # @rbs type: untyped
    #: (untyped) -> bool
    def can_be_false?(type)
      type.is_a?(Steep::AST::Types::Boolean) || type.is_a?(Steep::AST::Types::Logic::Base) ||
        (type.is_a?(Steep::AST::Types::Literal) && type.value == false) || instance_name(type) == "::FalseClass"
    end

    # @rbs type: untyped
    #: (untyped) -> bool
    def known?(type)
      case type
      when Steep::AST::Types::Any, Steep::AST::Types::Top, Steep::AST::Types::Bot, Steep::AST::Types::Var, Steep::AST::Types::Name::Alias, Steep::AST::Types::Void, Steep::AST::Types::Self, Steep::AST::Types::Instance, Steep::AST::Types::Class then false
      when Steep::AST::Types::Union then type.types.all? { known?(_1) }
      when Steep::AST::Types::Intersection then type.types.any? { known?(_1) }
      else true
      end
    end

    # @rbs type: untyped
    #: (untyped) -> bool
    def never_nil?(type)
      return false unless type && known?(type)
      return type.types.any? { never_nil?(_1) } if type.is_a?(Steep::AST::Types::Intersection)

      members(type).none? { nil_type?(_1) }
    end

    # @rbs type: untyped
    #: (untyped) -> bool
    def never_falsy?(type)
      return false unless never_nil?(type)
      return type.types.any? { never_falsy?(_1) } if type.is_a?(Steep::AST::Types::Intersection)

      members(type).none? { can_be_false?(_1) }
    end

    # @rbs type: untyped
    #: (untyped) -> bool
    def nilable?(type)
      known?(type) && members(type).any? { nil_type?(_1) } && members(type).any? { !nil_type?(_1) }
    end

    # A union of literals such as `:open | :closed`, possibly with nil.
    # @rbs type: untyped
    #: (untyped) -> bool
    def literal_union?(type)
      known?(type) && type.is_a?(Steep::AST::Types::Union) &&
        members(type).all? { _1.is_a?(Steep::AST::Types::Literal) || nil_type?(_1) } &&
        members(type).any? { _1.is_a?(Steep::AST::Types::Literal) }
    end

    # @rbs type: untyped
    # @rbs value: untyped
    #: (untyped, untyped) -> bool
    def includes_literal?(type, value) = members(type).any? { _1.is_a?(Steep::AST::Types::Literal) && _1.value == value }
  end
end
