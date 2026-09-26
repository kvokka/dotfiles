# cass update notes

State as of 2026-09-26. The pin is cass 0.9.0, set in `~/.config/mise/config.fw.toml` (in the dotfiles repo: `homedir/dot_config/mise/config.fw.toml`, kvokka/dotfiles PR #8, #12). Read this before changing the cass setup: the work below is done and measured.

## Done, do not redo

- **Freshness** comes from two pitchfork cron daemons:
  - `cass-index` runs `cass index --background --semantic` every 5 minutes. `--semantic` embeds new sessions as well (~6 s a pass). Without it, the vectors stop matching the database after the first new session, and cass turns semantic search off until the next night.
  - `cass-nightly` runs `mise run fw:cass-nightly` daily at 10:05 local time. That wrapper calls `cass schedule run --job nightly --force`, which does a full index plus semantic backfill.

  Rejected alternatives:
  - `cass schedule install` needs systemd, and the container has none.
  - `cass index --watch` keeps 1.9 GB resident.
  - Stale-on-read auto-refresh answers from the old index.
- **Model:** `CASS_SEMANTIC_EMBEDDER=multilingual-minilm`. `fw:bootstrap` installs it into the data dir (`~/.local/share/coding-agent-search`, a link to `~/proj/share/cass`) under `models/`: it downloads only when missing and fails loudly on error.
  - It was chosen over `all-MiniLM-L6-v2` on Russian and English paraphrase queries over real sessions: expected session in the top 5 for 11 of 16 queries, against 4 of 16. Do not re-evaluate.
- **Checks:** `mise run fw:doctor` covers:
  - index freshness;
  - both daemons scheduled, with their last run ok;
  - model installed;
  - semantic quality tier published.
- **Session retention:** Claude Code `cleanupPeriodDays` is already 99999, so transcripts stay on disk for cass to index.

## Expected failures (upstream, not our setup)

- Semantic search on ARM64 (cass #467) is fixed in 0.9.0 (frankensearch 0.6.1). The first quality backfill ran on 2026-09-26.
- **Lexical search never matches Cyrillic, or any word that is neither ASCII nor CJK.**
  - Cause: frankensearch-quill `CassAnalyzer` only tokenizes `[A-Za-z0-9]` and CJK.
  - One such word empties a mixed query: `mcp` finds 400 hits, `морф mcp` finds 0.
  - No flag or env var works around it.
  - Still unfixed on cass `main` and in quill 0.3.1. No upstream issue exists; the owner has a draft.
  - Until then, semantic search with the multilingual model is the only way to find Russian text.
- **Do not use the hash tier (`--model hash`) as a workaround.** It returns near-noise on this archive.

## When a new cass release ships

1. **Check the release for the fixes.**
   - Cyrillic: is `CassAnalyzer::analyze` in `crates/frankensearch-quill/src/scribe.rs` still limited to `is_ascii_alphanumeric()` and CJK?
2. **Try it on a copy of the data dir first.**
   - Run `cass models backfill --tier quality --embedder multilingual-minilm --batch-conversations 1 --json`.
   - Expect exit 0 and `embedder_id: multilingual-minilm-384`.
3. **Bump the pin** in `config.fw.toml` and run `mise install`.
4. **Run the first backfill:** `mise run fw:cass-nightly`.
   - The first quality backfill over ~130k messages takes an estimated 1-2 h at idle priority.
   - Afterwards `fw:doctor` should be all green.
5. **If the release fixes the tokenizer:** rebuild the lexical index with `mise run fw:cass-index` (full), unless the changelog says it rebuilds by itself.

## Gotchas

- **Keep the `fw:cass-nightly` wrapper.** `cass schedule run` reports `ok: true` in two failure cases, and the wrapper turns them into failures:
  - a day skipped because the index lock was busy (exit 7);
  - a failed semantic backfill (exit 20).
- **pitchfork cron:**
  - Schedules have 6 fields with seconds first, in local time.
  - A daemon's schedule is armed only after its first start.
  - After changing a schedule, run `mise daemons restart <name>`.
  - `pitchfork clean` drops stopped cron daemons, which disarms them.
- **Cost on ~1270 sessions, ~130k messages:**

  | run | time | peak RSS |
  |---|---|---|
  | incremental | ~5 s | 2.35 GB |
  | full | ~85 s | 4.1 GB |
  | nightly | ~105 s | 4.3 GB |
  | first nightly | ~8.5 min (builds the hash tier) | — |
  | first `index --semantic` after the quality backfill (0.9.0) | ~72 min | — |
  | incremental `--background --semantic` (0.9.0) | ~6 s | — |
