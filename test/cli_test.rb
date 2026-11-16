# frozen_string_literal: true

require "test_helper"
require "stringio"
require "tmpdir"

class CLITest < Minitest::Test
  def run_cli(*argv)
    out = StringIO.new
    err = StringIO.new
    status = Typegap::CLI.new(out: out, err: err).run(argv)
    [status, out.string, err.string]
  end

  def test_findings_exit_1_with_one_line_each
    status, out, err = run_cli("--root", File.join(Fixtures::DIR, "gaps"), "--only", "PreferFind,MisusedSplat")
    assert_equal 1, status
    assert_equal <<~TEXT, out
      lib/shop.rb:54:5: PreferFind: `select { ... }.first` on Array builds a whole list to take one; use `find { ... }`
      lib/shop.rb:55:6: MisusedSplat: `opts` is `::Hash[::Symbol, ::Integer]`; `*` splits it into [key, value] pairs. Use `**` for keywords
    TEXT
    assert_equal "2 findings\n", err
  end

  def test_json_prints_one_object_per_finding
    _, out, err = run_cli("--root", File.join(Fixtures::DIR, "gaps"), "--json", "--only", "PreferFind")
    assert_equal [{ "path" => "lib/shop.rb", "line" => 54, "column" => 5, "rule" => "PreferFind",
                    "message" => "`select { ... }.first` on Array builds a whole list to take one; use `find { ... }`" }],
                 out.lines.map { JSON.parse(_1) }
    assert_equal "", err
  end

  def test_no_finding_exits_0
    status, out, err = run_cli("--root", File.join(Fixtures::DIR, "clean"))
    assert_equal [0, "", "0 findings\n"], [status, out, err]
  end

  def test_a_path_limits_the_ruby_files_and_skips_signatures
    Dir.chdir(File.join(Fixtures::DIR, "gaps")) do
      _, out, = run_cli("--only", "GetterSetterMismatch,PreferFind", "lib/shop.rb")
      assert_equal ["lib/shop.rb:54:5: PreferFind"], out.lines.map { _1.split(": ").first(2).join(": ") }
    end
  end

  def test_an_unknown_rule_exits_2
    status, out, err = run_cli("--only", "Nope")
    assert_equal 2, status
    assert_equal "", out
    assert_match(/\Atypegap: unknown rule: Nope/, err)
  end

  def test_no_steepfile_exits_2
    Dir.mktmpdir do |dir|
      status, _, err = run_cli("--root", dir)
      assert_equal 2, status
      assert_match "no Steepfile", err
    end
  end

  def test_rules_lists_every_rule
    status, out, = run_cli("--rules")
    assert_equal 0, status
    assert_equal Typegap::Rules::NAMES, out.lines.map { _1[/\A\w+/] }
    assert_includes out, "UntypedCall (off by default): follows no-unsafe-call, no-unsafe-member-access\n"
  end
end
