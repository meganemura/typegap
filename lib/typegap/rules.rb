# frozen_string_literal: true
# rbs_inline: enabled

module Typegap
  # The rules, each with the typescript-eslint rule it ports. A rule that is
  # off by default reports too much to read as a list: it is a map to read
  # with `--only`.
  module Rules
    Rule = Data.define(:name, :follows, :default)

    ALL = [
      Rule.new("UnnecessarySafeNavigation", "no-unnecessary-condition", true),
      Rule.new("UnnecessaryNilCheck", "no-unnecessary-condition", true),
      Rule.new("AlwaysTruthyCondition", "strict-boolean-expressions, no-unnecessary-condition", true),
      Rule.new("UnnecessaryDefault", "no-unnecessary-condition (??)", true),
      Rule.new("OrReplacesFalse", "prefer-nullish-coalescing", true),
      Rule.new("UnnecessaryTypeCheck", "no-unnecessary-condition", true),
      Rule.new("UnnecessaryBooleanCompare", "no-unnecessary-boolean-literal-compare", true),
      Rule.new("UnnecessaryConversion", "no-unnecessary-template-expression, no-unnecessary-type-conversion", true),
      Rule.new("RestrictInterpolation", "restrict-template-expressions, no-base-to-string", true),
      Rule.new("CaseExhaustiveness", "switch-exhaustiveness-check", true),
      Rule.new("ImpossibleLiteralComparison", "no-unsafe-enum-comparison", true),
      Rule.new("UnusedResult", "no-floating-promises", true),
      Rule.new("VoidValueUsed", "no-confusing-void-expression", true),
      Rule.new("UnnecessaryTypeAssertion", "no-unnecessary-type-assertion", true),
      Rule.new("NilDroppingAssertion", "no-unsafe-type-assertion, non-nullable-type-assertion-style", true),
      Rule.new("SortWithoutComparable", "require-array-sort-compare", true),
      Rule.new("PreferFind", "prefer-find", true),
      Rule.new("MisusedSplat", "no-misused-spread", true),
      Rule.new("PredicateReturnType", "naming-convention", true),
      Rule.new("PreferReturnSelfType", "prefer-return-this-type", true),
      Rule.new("UnreachableBranch", "no-unnecessary-condition (Steep's own diagnostic)", true),
      Rule.new("DeprecatedReference", "no-deprecated (Steep's own diagnostic)", true),
      Rule.new("RedundantTypeConstituents", "no-redundant-type-constituents, no-duplicate-type-constituents", true),
      Rule.new("UnnecessaryTypeParameter", "no-unnecessary-type-parameters", true),
      Rule.new("GetterSetterMismatch", "related-getter-setter-pairs", true),
      Rule.new("UntypedCall", "no-unsafe-call, no-unsafe-member-access", false)
    ].freeze #: Array[Rule]

    NAMES = ALL.map(&:name).freeze #: Array[String]

    # The rule names that run: `only` when given, else every default rule,
    # less `except`. An unknown name raises, so a typo does not silently run
    # nothing.
    #
    # @rbs only: Array[String]?
    # @rbs except: Array[String]
    #: (only: Array[String]?, except: Array[String]) -> Array[String]
    def self.select(only:, except:)
      unknown = (only || []) + except - NAMES
      raise ArgumentError, "unknown rule: #{unknown.join(", ")} (rules: #{NAMES.join(", ")})" unless unknown.empty?

      (only || ALL.select(&:default).map(&:name)) - except
    end
  end
end
