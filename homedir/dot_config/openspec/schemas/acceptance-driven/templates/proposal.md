## Why

<!-- The problem or opportunity, in one or two sentences. Why now? -->

## What Changes

<!-- Specific new capabilities, modifications or removals. Mark breaking
     changes with **BREAKING**. -->

## Capabilities

### New Capabilities

<!-- Capabilities being introduced. Use kebab-case for path segments you
     introduce (e.g. user-auth or identity/user-auth) that follow the
     project's existing spec organization. Each creates
     specs/<capability-path>/spec.md. -->

- `<capability-path>`: <what this capability covers>

### Modified Capabilities

<!-- Existing capabilities whose REQUIREMENTS change (not just their
     implementation). Each needs a delta spec file. Use the exact existing
     path under openspec/specs/. Leave empty if no requirement changes.
     A change with no capabilities at all (pure refactor, tooling, docs) sets
     `skip_specs: true` in its .openspec.yaml - openspec validate rejects a
     zero-delta change without that marker. Do not invent a requirement to
     satisfy validation. -->

- `<existing-capability-path>`: <what requirement is changing>

## Impact

<!-- Affected code, APIs, dependencies, systems. -->

<!-- Artifacts open at heading level two on purpose: OpenSpec parses the
     level-two sections, and a level-one heading is taken as the change
     title instead. Markdown linters expect a top-level heading, so this
     file opts out of that one rule. -->
<!-- markdownlint-disable-file MD041 -->
