# acceptance-driven OpenSpec schema

A custom [OpenSpec](https://github.com/Fission-AI/OpenSpec) workflow schema for
projects that run execution from a tracker outside OpenSpec.

A change under this schema has four artifacts:

| Artifact       | File            | Holds                                        |
| -------------- | --------------- | -------------------------------------------- |
| `proposal`     | `proposal.md`   | Why the change is needed and what it changes  |
| `acceptance`   | `acceptance.md` | Originating criteria, evidence and notes      |
| `specs`        | `specs/**/*.md` | Delta specs for the behavior that changes     |
| `design`       | `design.md`     | Optional: how it is built and why that way    |

There is no implementation checklist. Execution steps, their order, progress
and ownership belong to the external execution tracker the project already
uses, so the schema neither generates nor tracks `tasks.md`.

Two consequences follow from that, both of them deliberate:

- `acceptance.md` is not a completion gate. A change can be archived while
  criteria are still unverified; the file travels into the archive and keeps
  receiving checkmarks, evidence and notes there.
- A change that changes no specified behavior carries no spec delta. Set
  `skip_specs: true` in the change's `.openspec.yaml` rather than inventing a
  requirement to satisfy `openspec validate`.

## Install

Resolution order is project, then user, then the built-in schemas, and the
directory name is the schema name. Link or copy this directory as
`acceptance-driven` into either location:

```sh
# For one project
ln -s /path/to/openspec-schema <project>/openspec/schemas/acceptance-driven

# For every project on this machine
ln -s /path/to/openspec-schema \
  "${XDG_DATA_HOME:-$HOME/.local/share}/openspec/schemas/acceptance-driven"
```

Then check it resolves and use it:

```sh
openspec schema which acceptance-driven
openspec schema validate acceptance-driven
openspec new change <name> --schema acceptance-driven
```

Set `schema: acceptance-driven` in `openspec/config.yaml` to make it a
project's default.

Requires an OpenSpec CLI with custom schema support; verified against 1.11.
