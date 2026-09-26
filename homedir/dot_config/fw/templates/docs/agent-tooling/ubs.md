# ubs

How the Ultimate Bug Scanner works on this machine and which parts of its behaviour are easy to trip over. Open upstream problems and the release check are in [upstream-todo.md](upstream-todo.md#ubs).

## How it works

- **Pin:** `ubs` 5.4.9 in `~/.config/mise/config.fw.toml`.
- **Language modules:** the first run downloads them from the release tag into `~/.local/share/ubs/modules`. In a fresh container, the first scan takes a few minutes.
- **Gate:** the `ubs` hook of the repository's `.pre-commit-config.yaml` runs `env UBS_ALLOW_NO_SCAN=1 UBS_SKIP_RUST_BUILD=1 ubs --ci` on the staged files. It is the only gate: agents get no ubs instructions and fix what the hook reports; `ubs <files>` reproduces a finding.
- **Exit codes:**
  - 0: clean.
  - 1: at least one critical finding. Warnings do not fail the run without `--fail-on-warning`.
  - 2: an environment error, a refused scan or a partial run.
  - 3: nothing was scanned; the hook turns it into 0 through `UBS_ALLOW_NO_SCAN=1`.
- **Noise control:**
  - `.ubsignore` holds path globs; the template ships one.
  - A trailing `ubs:ignore -- <reason>` on the flagged line, or the same marker on the line above, suppresses the finding.
  - `--skip-<lang>=N` turns off a category in one language. Category numbers differ between languages.
  - `ubs explain <rule-id>` explains a rule and how to fix what it flags.

## Custom rules

Custom rules are not wired. The design waits for the upstream decision on shared rule packs ([upstream-todo.md](upstream-todo.md#ubs)); do not build it before then.

What holds in 5.4.9:

- `--rules=DIR` is the only way in: one directory, taken from the flag only. No config file or environment variable sets it. A missing directory is ignored silently.
- A rule is ast-grep YAML. For `severity`, use ast-grep's levels:
  - `error` is reported as critical and fails the commit;
  - `warning` is reported as warning;
  - `info` and `hint` are reported as info.

  `critical` is not an ast-grep level: the rule fails to parse, and the run exits 2.
- The Python module loads only the top-level files of the rules directory, so keep the directory flat.
- cass-memory rules are not a source for ubs rules. cm cuts the middle out of each session (it keeps about the first and last 25 000 characters) and keeps only a prose summary, so the code of a bug never reaches its rules.
