# 0002 Stay silent where the type is not trusted

## Context

The rules turn a type into a claim about the code: never nil, always an Integer, one of these literals.
A claim from a type that is wrong in a known way is a false finding, and false findings teach the reader to ignore the true ones.
On six real gems typed with rbs-inline, most false findings came from three places: RBS core methods typed as never nil that return nil (`Hash#[]`, `Array#first`, `Thread#join`), instance variables read before they are set, and assertions that give a literal its type (`false #: bool`).

## Decision

A rule reports only from a type Steep knows completely.
It stays silent on `untyped`, a type variable, `self`, an alias Steep did not expand, a value from a call in `SourceCheck::NIL_HIDING_CALLS`, and an instance variable.
Steep's own unreachable-branch hint is dropped when the branch is decided by one of those values.
An assertion on a literal, an empty or literal collection, nil, or `.new` is never reported as unnecessary, because Steep types those from the assertion.

## Consequences

typegap misses some real gaps behind these values.
A new false finding is fixed by adding its source to these lists, with a case in `test/fixtures/clean`, not by a per-rule exception.
