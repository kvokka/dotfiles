# cass

How cass works on this machine and which parts of its setup look odd but are deliberate. The settings and the reasons behind them are in `~/.config/mise/config.fw.toml` (dotfiles: `homedir/dot_config/mise/config.fw.toml`). Open upstream problems and the release check are in [upstream-todo.md](upstream-todo.md#cass).

## How it works

- **Data:** the default data dir `~/.local/share/coding-agent-search`, a link to `~/proj/share/cass`.
- **Freshness:** two pitchfork cron daemons.
  - `cass-index`: `cass index --background --semantic` every 5 minutes, about 6 s.
  - `cass-nightly`: daily at 10:05 local time, `mise run fw:cass-nightly`, which is `cass schedule run --job nightly --force`: a full index plus semantic backfill, about 105 s and 4.3 GB peak RSS.
- **Search:** hybrid, lexical (ASCII and CJK tokens) plus semantic; only the semantic part reaches Russian text. The embedder is `multilingual-minilm` (`CASS_SEMANTIC_EMBEDDER`); `fw:bootstrap` installs it when it is missing.
- **Check:** `mise run fw:doctor` reports index freshness, both daemons, the model and the published semantic tier.

## Quirks

- **Lexical search misses Cyrillic.** It indexes only ASCII and CJK words. A single Russian word empties a mixed query: `mcp` finds hits, `морф mcp` finds none. Search Russian text semantically, or use English keywords.
- **Keep `--semantic` in `cass-index`.** Without it, the vectors stop matching the database after the first new session, and cass turns semantic search off until the next nightly run.
- **Keep the `fw:cass-nightly` wrapper.** `cass schedule run` exits non-zero on a busy index lock (a step with exit 7, which the wrapper retries every 60 s) and reports `ok: true` for a skipped semantic backfill (a step with exit 15 or 20-24). The wrapper decides from the steps in the JSON instead, and fails on the skipped backfill too.
- **Not these alternatives:**
  - `cass schedule install` needs systemd, which the container does not have.
  - `cass index --watch` keeps 1.9 GB resident.
  - The hash tier (`--embedder hash`, or `CASS_SEMANTIC_EMBEDDER=hash`) returns near-noise on this archive.
- **pitchfork cron:**
  - A schedule has 6 fields, seconds first, in local time.
  - The supervisor arms a schedule from the config mise registered (the shell hook, `mise daemons register`) within its 10 s check; a registered daemon that has not run yet is `available`. After a schedule change, run `mise daemons restart <name>`.
  - `pitchfork clean` removes a stopped cron daemon's entry; the supervisor registers it again within 10 s, anchored to now, so a run due in between is skipped.
- **Retention:** Claude Code's `cleanupPeriodDays` is 99999, so transcripts stay on disk for cass to index.
