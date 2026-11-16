# Changelog

## [Unreleased]

First release. typegap reports where a Ruby project's RBS types and its code disagree, on the typing Steep infers.

- 25 rules that port typescript-eslint's type-aware rules, and UntypedCall, which is off by default. `typegap --rules` lists them with the rule each follows.
- `typegap [--json] [--only RULES] [--except RULES] [--root DIR] [PATH...]` prints one finding per line, or one JSON object per finding, and exits 1 when it finds one.
- The rules stay silent on a value from `Hash#[]`, `Array#first`, and other calls RBS core types as never nil, and on an instance variable, since each can be nil whatever its type says.
- Steep's unreachable-branch hint and deprecation warning are reported as UnreachableBranch and DeprecatedReference, except a branch decided by one of those values.
- Steep 2.1 on Ruby 3.3 or later.
