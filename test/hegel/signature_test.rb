# frozen_string_literal: true

require "test_helper"
require "hegel"

# The signature rules claim a type says less than it seems to. These
# properties build signatures from parts and compare each finding with what
# the parts make true.
class SignatureTest < Minitest::Test
  include Hegel::Syntax::Methods

  SETTINGS = { test_cases: 300, seed: 7 }.freeze
  ATOMS = %w[String Integer Symbol nil :a 1 untyped bool true false Array[String]].freeze

  def findings(rbs)
    Typegap::SignatureCheck.new("sig/a.rbs", rbs, Typegap::Rules::NAMES).findings
  end

  def test_a_union_is_reported_exactly_when_a_member_is_untyped_repeated_or_covered_by_bool
    Hegel.test(**SETTINGS) do |tc|
      atoms = tc.draw(arrays(sampled_from(ATOMS), min_size: 2, max_size: 5))
      found = findings("class A\n  def m: () -> (#{atoms.join(" | ")})\nend\n").map(&:message)

      assert_equal atoms.include?("untyped"), found.any? { _1.include?("contains `untyped`") }
      assert_equal atoms.size != atoms.uniq.size, found.any? { _1.include?("twice") }
      assert_equal atoms.include?("bool") && atoms.intersect?(%w[true false]), found.any? { _1.include?("true or false literal") }
    end
  end

  def test_a_type_parameter_is_reported_exactly_when_it_is_used_once_or_never
    Hegel.test(**SETTINGS) do |tc|
      params = tc.draw(arrays(sampled_from(%w[T Integer]), max_size: 3))
      result = tc.draw(sampled_from(%w[T void]))
      block = tc.draw(sampled_from(["", " { (T) -> void }", " { () -> Integer }"]))
      uses = params.count("T") + (result == "T" ? 1 : 0) + (block.include?("(T)") ? 1 : 0)
      found = findings("class A\n  def m: [T] (#{params.join(", ")})#{block} -> #{result}\nend\n")

      assert_equal uses <= 1, found.any? { _1.rule == "UnnecessaryTypeParameter" }, "uses #{uses}"
    end
  end

  def test_a_getter_and_setter_are_reported_exactly_when_their_types_differ
    Hegel.test(**SETTINGS) do |tc|
      read = tc.draw(sampled_from(%w[String Integer String?]))
      write = tc.draw(sampled_from(%w[String Integer String?]))
      setter = tc.draw(booleans) ? "attr_writer size: #{write}" : "def size=: (#{write}) -> #{write}"
      found = findings("class A\n  attr_reader size: #{read}\n  #{setter}\nend\n")

      assert_equal read != write, found.any? { _1.rule == "GetterSetterMismatch" }
    end
  end
end
