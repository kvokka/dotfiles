# deja

How deja works on this machine and which parts of its setup look odd but are deliberate. The settings and the reasons behind them are next to them: `~/.config/mise/config.linux.toml` for the tool, `DEJA_EMBED_*` and the daemon.

This directory is deja's own: it keeps `wiring.json`, `policy.json`, `rules.md` and more here and opens each by name, so it never sees this file. Only the README comes from chezmoi.

## How it works

- **Install:** the mise tool `npm:@vshulcz/deja-vu` and the Claude Code plugin `deja-vu@deja-vu`.
- **Data:** `~/.cache/deja`; vectors in `index.db.vectors.bin`, about 4 MB per 1k records.
- **Search:** lexical plus a semantic tier. The vectors are `voyage-4-large` through MongoDB's Voyage endpoint, the `DEJA_EMBED_*` of `[env]`.
- **Key:** `DEJA_EMBED_KEY` in fnox, the API key of MongoDB's Voyage endpoint. The URL is a plain setting in `[env]`.
- **Freshness:** the pitchfork cron daemon `deja-embed` runs `deja embed` hourly and adds only new records: 2 to 10 s and about 740 MB, and it rewrites the whole sidecar even with nothing new.
- **Check:** `deja doctor --offline` in an interactive shell reports the model and the embedded share.

## Quirks

- **The binary is a local build.** `npm-vshulcz-deja-vu/0.24.0/node_modules/@vshulcz/deja-vu-linux-arm64/bin/deja` is v0.24.0 plus `DEJA_EMBED_FLOOR`, with the release build next to it as `deja.orig-0.24.0`. A fresh install or a reinstall brings the release back: nothing fails, the variable is ignored and the floor is 0.55 again. Upstream will not take the variable; what replaces it is under [Upstream](#upstream).
- **A search with vectors takes 2 to 4 s and about 800 MB.** That is an MCP recall or a CLI `search`, each time, not only the first: most of it is `ReadRecords` unpacking the whole record log, then the query embedding. Fixed after 0.24.0 (#5979, in nightly): only the best records' offsets are read. Hooks never read the vectors. `deja search --no-embed` takes about 0.1 s.
- **Another model or passage prefix embeds everything again:** about 16M tokens and 25 minutes at 72k records. Search stays lexical and says so while the client and the sidecar disagree.
- **A process started without `DEJA_EMBED_*` stays lexical.** gc agents run under the supervisor's environment, so check there before expecting vectors. `deja embed` itself must see the variables, hence `mise x` in the daemon.
- **A non-interactive shell has no key,** like every other fnox secret. Use `fnox exec --`.

## Hooks and subagents

What the hooks give an agent, measured on 2026-11-08 against deja 0.24.0's source and replayed payloads of real sessions. No `DEJA_*` variable makes them more useful, so `[env]` sets none of them.

- **A subagent gets almost nothing, by design.** The plugin's PreToolUse on `Task|Agent` returns nothing for Claude Code (`hook_spawn.go:71`): since 0.23.2 the recall block is added to a subagent's prompt only for Grok. Upstream measured 1339 subagents that were handed one and none that used it. A subagent has no SessionStart or UserPromptSubmit, and deja registers no `SubagentStart`, although Claude Code has it. What reaches a subagent is the file note before an Edit or Write. It is deduplicated with the parent's, because a subagent's hooks get the parent's `session_id`.
- **A subagent's report is never indexed.** It reaches the parent as an `isMeta` user record, which deja skips (`claude.go:362`). Its task, edits, commands and last turns are indexed as a sidechain of its own, but recall leaves the asking session's own children out. A finding is remembered only once the parent has said it in its own words.
- **`DEJA_INCLUDE_SUBAGENTS` stays unset.** Unset keeps a subagent's task, edits and last 4 turns; `=1` keeps the whole run, which made the index 2 to 3 times larger and the prompt hook silent more often, and brought back no finding; `=0` drops subagents. A change applies only to files read later, unless you run `deja index --rebuild`.
- **`DEJA_COMMAND_HINTS` stays unset.** Only `on` turns the line before a command on. Upstream measured that it does not change how often a command fails (2.7% against 3.0%). It also never fires on a command that begins `export ...;` or `cd ...`, since its key is the first word before `;|&`: that is most of an agent's commands here.
- **`DEJA_RECALL` stays unset (`safe`).** `aggressive` adds the sessions of 12 recent projects to SessionStart, here gc's worker agents (`bd.dog`), which is noise. `off` silences every hook, the one useful prompt recall too.
- **A trap from a command that succeeds is never warned about.** The hook after a command speaks only on a failure. `deja remember` writes a plain note, which search and recall rank first but the hook before a command does not read. Rules that must hold, write in an AGENTS.md or CLAUDE.md, which every agent and subagent sees.
- **A fix from another project is not offered after a failure.** `hook-tool-after` looks only in the current project (`hook_tool_after.go:486-492`), so the quoting fix for zsh's `no matches found` that `deja fix` knows stays unseen.

## Upstream

Pin: 0.24.0 plus a local build.

- **The semantic floor is a fixed 0.55.** It drops about half of `voyage-4-large`'s right answers. [vshulcz/deja-vu#5970](https://github.com/vshulcz/deja-vu/issues/5970). The fix with `DEJA_EMBED_FLOOR`, [#5971](https://github.com/vshulcz/deja-vu/pull/5971), was closed unmerged on 2026-11-07: upstream wants no setting for it. [#5980](https://github.com/vshulcz/deja-vu/pull/5980), merged the same day, calibrates the floor itself: 0.40 for `voyage-*` and other low-cosine models, otherwise from the median when it is low. As of 2026-11-08 it is in no release, not even the nightly.
  - When a release has #5980: bump the pin with `mise upgrade`, which removes the local build, drop `DEJA_EMBED_FLOOR` and its comments from `config.linux.toml`, and drop this item and the local-build quirk above.
  - If search misbehaves before that: `deja.orig-0.24.0` next to the binary is the release build. Move it back and drop the variable; everything but the floor stays the same.
- **Next release: `.deja/memory.jsonl` in a checkout.** Nightly writes a repo memory file into the git checkout it works in, from the SessionStart digest refresh and MCP orient: an untracked file in every repo and worktree. `DEJA_REPO=off` or `deja repo off` turns it off. Decide before the upgrade.
