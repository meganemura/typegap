# frozen_string_literal: true

require "test_helper"

class RulesTest < Minitest::Test
  # test/fixtures/gaps holds one gap per rule. Its expected.txt is the exact
  # output; regenerate it with `exe/typegap --root test/fixtures/gaps --only
  # <every rule>` and read the diff.
  def test_the_gaps_fixture_reports_exactly_its_expected_findings
    expected = File.read(File.join(Fixtures::DIR, "gaps", "expected.txt")).lines(chomp: true)
    assert_equal expected, Fixtures.findings("gaps").map(&:to_s)
  end

  # UntypedCall needs a call on `untyped`, which a fully typed fixture has none of.
  def test_every_rule_but_untyped_call_has_a_gap_in_the_fixture
    assert_equal (Typegap::Rules::NAMES - ["UntypedCall"]).sort, Fixtures.findings("gaps").map(&:rule).uniq.sort
  end

  # test/fixtures/clean holds code a reader would keep, in the shapes a rule
  # once reported by mistake: nil from Hash#[], an instance variable before
  # it is set, a default after `||`, a conversion with a block, an assertion
  # that widens a literal.
  def test_the_clean_fixture_reports_nothing
    assert_equal [], Fixtures.findings("clean").map(&:to_s)
  end

  def test_a_rule_left_out_reports_nothing
    rules = Typegap::Rules::NAMES - ["UnusedResult"]
    found = Fixtures.findings("gaps", rules: rules)
    refute_includes found.map(&:rule), "UnusedResult"
    assert_includes found.map(&:rule), "SortWithoutComparable"
  end

  def test_select_runs_the_default_rules_less_the_excepted_ones
    selected = Typegap::Rules.select(only: nil, except: ["PreferFind"])
    refute_includes selected, "UntypedCall"
    refute_includes selected, "PreferFind"
    assert_includes selected, "UnusedResult"
    assert_equal ["UntypedCall"], Typegap::Rules.select(only: ["UntypedCall"], except: [])
  end

  def test_select_refuses_an_unknown_rule
    error = assert_raises(ArgumentError) { Typegap::Rules.select(only: ["UnusedResults"], except: []) }
    assert_match "unknown rule: UnusedResults", error.message
  end
end
