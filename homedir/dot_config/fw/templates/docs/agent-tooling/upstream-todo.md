# Upstream todo

Open upstream problems of the agent-stack tools, what to check when a new release ships, and what to change here once a problem is fixed. Pins live in `~/.config/mise/config.fw.toml` (dotfiles: `homedir/dot_config/mise/config.fw.toml`).

Read the tool's section before bumping its pin. Remove an item once the fix is released and adopted here; how the setup worked before does not belong here.

## cass

Pin: 0.9.0. Setup notes: [cass.md](cass.md).

- **Lexical search tokenizes only ASCII and CJK.** Russian words never match, and one Russian word empties a mixed query. No upstream issue exists yet.
  - Check: does `CassAnalyzer::analyze` in `crates/frankensearch-quill/src/scribe.rs` still keep only `is_ascii_alphanumeric()` and CJK?
  - When fixed: rebuild the lexical index with `mise run fw:cass-index`, unless the changelog says cass rebuilds it itself. Then drop the Cyrillic quirk from [cass.md](cass.md) and the English-keywords line from the instruction block `~/.config/fw/instructions/cass.md`.
- **Every release:**
  1. On a copy of the data dir, run `cass models backfill --tier quality --embedder multilingual-minilm --batch-conversations 1 --json`. It should exit 0 and report `embedder_id: multilingual-minilm-384`.
  2. Bump the pin and run `mise install`.
  3. Run `mise run fw:cass-nightly`, then `mise run fw:doctor`. The doctor should be all green.

## ubs

Pin: 5.4.9. Setup notes: [ubs.md](ubs.md).

- **Shared rule packs**: [issue #144](https://github.com/Dicklesworthstone/ultimate_bug_scanner/issues/144), illustrated by [PR #145](https://github.com/Dicklesworthstone/ultimate_bug_scanner/pull/145). Requested: a repeatable `--rules`, a `UBS_RULES` environment variable, and git rule packs (`git+URL[@REF][#subdirectory=DIR]`). The issue also reports two defects: rules in subdirectories are skipped by the Python module, and the README's `severity: critical` example does not parse.
  - The design of custom rules for this setup waits for the author's answer here: a separate rules repository whose rules every project hook loads. The upstream answer decides how the hook gets those rules.
  - Check: the release notes and the `--rules` entry of `ubs --help`.
- **Newer versions refuse a missing or empty `--rules` directory** (on `main` after 5.4.9). 5.4.9 ignores it silently. Once the hook passes `--rules`, make sure the directory always exists.
- **Every release:** after bumping the pin, commit once in a repository that has the template's `.pre-commit-config.yaml`. The first run downloads the new modules.

## cass-memory (cm)

Pin: a `main` commit, built from the source tarball.

- **No linux-arm64 release binary** (0.2.14 ships linux-x64, macOS and Windows only). This is why `cm` is built from source with the `http:` backend.
  - Check: the assets of the new release.
  - When one ships: switch to a `github:` release pin and drop the `postinstall` build.
