# 0001 Read Steep's typing

## Context

A rule such as "this `&.` is not needed" needs the type of the receiver at that point in the code.
Inferring types again would be a second type checker that disagrees with Steep in places, and a finding would then mean what typegap inferred, not what the project's own type check says.
Steep has no public API for the typing of a file.
Its language server and `steep check` build it with `Steep::Services::TypeCheckService`.

## Decision

typegap loads the project from its `Steepfile` and asks `TypeCheckService` for each file's typing and its target's RBS definition builder.
`Typegap::Project` is the one file that touches that service.
The gemspec allows one minor version of Steep, the one the tests run with.

## Consequences

A finding names a type Steep inferred, so `steep check` and typegap never disagree about a type.
A new Steep minor version needs a typegap release that allows it, after the tests pass on it.
When Steep gains a public API for a file's typing, `Typegap::Project` moves to it, and nothing else changes.
