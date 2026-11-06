# deja

How deja works on this machine and which parts of its setup look odd but are deliberate. The settings and the reasons behind them are in `~/.config/mise/config.linux.toml`.

## How it works

- **Install:** the mise tool `npm:@vshulcz/deja-vu` and the Claude Code plugin `deja-vu@deja-vu`.
- **Data:** `~/.cache/deja`; vectors in `index.db.vectors.bin`, about 4 MB per 1k records.
- **Search:** lexical plus a semantic tier. The vectors are `voyage-4-large` through MongoDB's Voyage endpoint, the `DEJA_EMBED_*` of `[env]`, the key `DEJA_EMBED_KEY` in fnox.
- **Freshness:** the pitchfork cron daemon `deja-embed` runs `deja embed` hourly and adds only new records: 2 to 10 s and about 740 MB, and it rewrites the whole sidecar even with nothing new.
- **Check:** `fnox exec -- deja doctor --offline` reports the model and the embedded share.

## Quirks

- **The binary is a local build.** `npm-vshulcz-deja-vu/0.24.0/node_modules/@vshulcz/deja-vu-linux-arm64/bin/deja` is v0.24.0 plus `DEJA_EMBED_FLOOR`, with the release build next to it as `deja.orig-0.24.0`. A fresh install or a reinstall brings the release back: nothing fails, the variable is ignored and the floor is 0.55 again. The fix is in [upstream-todo.md](upstream-todo.md).
- **A search with vectors takes 2 to 4 s and about 800 MB.** That is an MCP recall or a CLI `search`, each time, not only the first: most of it is `ReadRecords` unpacking the whole record log, then the query embedding. Hooks never read the vectors. `deja search --no-embed` takes about 0.1 s.
- **Another model or passage prefix embeds everything again:** about 16M tokens and 25 minutes at 72k records. Search stays lexical and says so while the client and the sidecar disagree.
- **A process started without `DEJA_EMBED_*` stays lexical.** gc agents run under the supervisor's environment, so check there before expecting vectors. `deja embed` itself must see the variables, hence `mise x` in the daemon.
