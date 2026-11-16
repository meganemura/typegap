# typegap

typegap finds the places where a Ruby project's RBS types and its code disagree.

Steep reports code that breaks its types.
typegap reports code that its types make unnecessary, impossible, or easy to misuse: a `&.` on a value the type says is never nil, a `case` that misses a member of a union, a `sort` on elements that cannot compare.
Each rule ports a type-aware rule of [typescript-eslint](https://typescript-eslint.io/rules/), and reads the types Steep infers instead of inferring its own.

In a codebase typed with RBS, most findings are a gap between the type and the code, not dead code.
When `x&.name` is reported because `x` is typed as never nil, either the `&.` is not needed or the type says too much.
The finding does not say which; the reader decides.

## Getting started

Add typegap to a project that type checks with Steep:

```ruby
# Gemfile
gem "typegap", require: false
```

Run it where the `Steepfile` is:

```console
$ bundle exec typegap
lib/shop.rb:28:5: UnnecessarySafeNavigation: `name` is `::String`, never nil, so `&.` is not needed
lib/shop.rb:43:5: CaseExhaustiveness: `status` is `(:open | :closed)`, but no `when` handles `:closed` and there is no `else`
lib/shop.rb:52:5: SortWithoutComparable: `::Point` has only Object#<=>, so `sort` raises ArgumentError. Pass a block or `sort_by`
3 findings
```

typegap exits 1 when it finds a gap, 0 when it finds none, and 2 when it cannot run.
A CI job can run it after `steep check`.

```console
$ bundle exec typegap --json            # one JSON object per finding
$ bundle exec typegap lib/shop.rb       # only these Ruby files (signature files are skipped)
$ bundle exec typegap --only CaseExhaustiveness,SortWithoutComparable
$ bundle exec typegap --except UnusedResult
$ bundle exec typegap --rules           # every rule and the typescript-eslint rule it follows
```

## Rules

| Rule | Reports | Follows |
| --- | --- | --- |
| UnnecessarySafeNavigation | `&.` on a value whose type has no nil | no-unnecessary-condition |
| UnnecessaryNilCheck | `nil?`, `== nil` on a value whose type has no nil | no-unnecessary-condition |
| AlwaysTruthyCondition | a condition whose type is never nil or false | strict-boolean-expressions |
| UnnecessaryDefault | `x \|\| default` where `x` is never nil or false | no-unnecessary-condition |
| OrReplacesFalse | `x \|\| default` where `x` can be false, which `\|\|` replaces too | prefer-nullish-coalescing |
| UnnecessaryTypeCheck | `is_a?`, `kind_of?`, `Class === x`, `respond_to?` the type already answers | no-unnecessary-condition |
| UnnecessaryBooleanCompare | `== true` on a `bool` | no-unnecessary-boolean-literal-compare |
| UnnecessaryConversion | `.to_s`, `"#{x}"`, `Integer(x)` on a value of that class | no-unnecessary-type-conversion |
| RestrictInterpolation | interpolating nil, a collection, or an object with no `to_s` of its own | restrict-template-expressions |
| CaseExhaustiveness | a `case` on a union of literals or classes that misses a member and has no `else` | switch-exhaustiveness-check |
| ImpossibleLiteralComparison | `==` against a literal the type cannot hold | no-unsafe-enum-comparison |
| UnusedResult | `strip`, `map`, `sort` and other copies whose result is dropped | no-floating-promises |
| VoidValueUsed | using the value of a method typed `void` | no-confusing-void-expression |
| UnnecessaryTypeAssertion | a `#:` assertion that repeats the inferred type | no-unnecessary-type-assertion |
| NilDroppingAssertion | a `#:` assertion that removes nil without a check | no-unsafe-type-assertion |
| SortWithoutComparable | `sort`, `min`, `max` on elements with no `<=>` among them | require-array-sort-compare |
| PreferFind | `select { }.first` | prefer-find |
| MisusedSplat | `*` on a Hash | no-misused-spread |
| PredicateReturnType | a `?` method that does not return `bool` | naming-convention |
| PreferReturnSelfType | a method that returns `self` typed as its class | prefer-return-this-type |
| UnreachableBranch | Steep's own unreachable-branch hint, which `steep check` hides by default | no-unnecessary-condition |
| DeprecatedReference | a call to a method marked `%a{deprecated}` | no-deprecated |
| RedundantTypeConstituents | `String \| untyped`, `String \| String`, `bool \| true`, `String??` in a signature | no-redundant-type-constituents |
| UnnecessaryTypeParameter | a method type parameter used once | no-unnecessary-type-parameters |
| GetterSetterMismatch | a getter and a setter of the same name with different types | related-getter-setter-pairs |
| UntypedCall (off by default) | each call on `untyped` | no-unsafe-call |

UntypedCall reports too much to read as a list in most projects.
Run it with `--only UntypedCall` to see where the types run out.

## What typegap distrusts

RBS core types some methods as never nil although they return nil: `Hash#[]` on a missing key, `Array#first` on an empty array.
An instance variable is nil before it is set, whatever its type says.
typegap stays silent on a value from these, because trusting the type there would report the very nil check that keeps the code safe.
It also stays silent on `untyped`, a type variable, `self`, and an alias Steep did not expand.

## Requirements

Ruby 3.3 or later, and Steep 2.1.
typegap reads Steep's type check service, which is not a public API, so each typegap version allows one minor version of Steep.

## License

MIT. See [LICENSE](LICENSE).

[Japanese](README.ja.md)
