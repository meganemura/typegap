# AGENTS.md

Context for agents that work in this repository.

## What this is

typegap reports where a Ruby project's RBS types and its code disagree. Its rules port the type-aware rules of typescript-eslint, on the typing Steep infers.
A finding carries no severity. The rule name says what kind of gap it is, and the reader decides whether the code or the type is wrong.
The design records are in `docs/decisions/`. Read them before you change the shape.

## Layout

- `lib/typegap.rb` is the entry: `Typegap.run(root:, paths:, rules:)`. `lib/typegap/cli.rb` is the `typegap` command.
- `lib/typegap/project.rb` is the one file that touches Steep's type check service (`docs/decisions/0001-read-steeps-typing.md`).
- `lib/typegap/source_check.rb` holds the rules that read a Ruby file's typing, and `signature_check.rb` the rules that read a signature file. `type_facts.rb` says what a Steep type says about nil, false, and classes. `rules.rb` lists every rule with the typescript-eslint rule it follows.
- `test/fixtures/gaps/` holds one gap per rule, and `expected.txt` is its exact output. `test/fixtures/clean/` holds code that must report nothing.
- `test/hegel/signature_test.rb` builds signatures from parts and compares each finding with what the parts make true.

## Visibility

This repository is intended for public release.
Write all committed text in English: code, comments, docs, commit messages.
`README.ja.md` is the one Japanese file. It follows `README.md` in the same commit, in natural Japanese, one sentence per line, with no em dash.
Do not reference private tools, private repositories, or internal working documents in committed content.

## Rules

- The one runtime dependency is `steep`, allowed at one minor version. The Gemfile pins the development versions exactly. Add a dependency only with the owner's approval, pinned exactly, at least 7 days past its release.
- A rule reports only from a type Steep knows completely, and stays silent where the type is known to lie (`docs/decisions/0002-silent-where-the-type-is-not-trusted.md`). A false finding is fixed by a case in `test/fixtures/clean/`.
- A new rule gets a gap in `test/fixtures/gaps/`, a row in `Rules::ALL` and in the README's table, and a line in `CHANGELOG.md`.
- A change to `lib/` keeps `bundle exec steep check` green, regenerates `sig/generated/` in the same commit, and keeps `bundle exec exe/typegap` at 0 findings on this repository. Write `#:` and `# @rbs` types on every method and constant. A Steep or Parser method that `lib/` starts to call goes into `sig-deps/`.
- Write property tests with hegeltest wherever a property exists.
- Comments say why: the constraint, or the alternative that was refused. Each file starts with its responsibility.
- A release or a change of the repository's visibility is the owner's to run. A commit that changes `lib/typegap/version.rb` and lands on `main` starts `.github/workflows/release.yml`; `docs/releasing.md` has the steps. Every change that a gem user can notice adds a line under `## [Unreleased]` in `CHANGELOG.md`.

## Commands

- `bundle exec bin/test` runs every test. `bundle exec bin/test test/rules_test.rb` runs one file.
- `BUNDLE_WITHOUT=hegel:types bundle exec bin/test test/rules_test.rb test/cli_test.rb` runs on Ruby 3.3, which hegeltest does not support.
- `bundle exec exe/typegap --root test/fixtures/gaps --only $(bundle exec exe/typegap --rules | cut -d: -f1 | cut -d' ' -f1 | paste -sd,) > test/fixtures/gaps/expected.txt` rewrites the golden output. Read the diff.
- `bundle exec rbs-inline --output=sig/generated lib` writes `sig/generated/` from the comments in `lib/`.
- `bundle exec steep check` checks `lib/` against `sig/` and `sig-deps/`. `bundle exec exe/typegap` runs typegap on itself.
