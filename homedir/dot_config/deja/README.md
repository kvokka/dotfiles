# deja

How deja works on this machine and which parts of its setup look odd but are deliberate. The settings and the reasons behind them are next to them: `~/.config/mise/config.linux.toml` for the tool, `DEJA_EMBED_*` and the daemon, `~/.config/zshrc.d/800-secrets.zsh` for the key in the shell.

This directory is deja's own: it keeps `wiring.json`, `policy.json`, `rules.md` and more here and opens each by name, so it never sees this file. Only the README comes from chezmoi.

## How it works

- **Install:** the mise tool `npm:@vshulcz/deja-vu` and the Claude Code plugin `deja-vu@deja-vu`.
- **Data:** `~/.cache/deja`; vectors in `index.db.vectors.bin`, about 4 MB per 1k records.
- **Search:** lexical plus a semantic tier. The vectors are `voyage-4-large` through MongoDB's Voyage endpoint, the `DEJA_EMBED_*` of `[env]`.
- **Key:** fnox's `MONGODB_API_KEY`, there is no second secret. deja reads only `DEJA_EMBED_KEY`, so the name is mapped twice. In the shell a precmd hook behind fnox's own sets it, and Claude Code, its MCP server and its hooks inherit it from the shell they start in. The daemon sets it in its `run`.
- **Freshness:** the pitchfork cron daemon `deja-embed` runs `deja embed` hourly and adds only new records: 2 to 10 s and about 740 MB, and it rewrites the whole sidecar even with nothing new.
- **Check:** `deja doctor --offline` in an interactive shell reports the model and the embedded share.

## Quirks

- **The binary is a local build.** `npm-vshulcz-deja-vu/0.24.0/node_modules/@vshulcz/deja-vu-linux-arm64/bin/deja` is v0.24.0 plus `DEJA_EMBED_FLOOR`, with the release build next to it as `deja.orig-0.24.0`. A fresh install or a reinstall brings the release back: nothing fails, the variable is ignored and the floor is 0.55 again. The fix is under [Upstream](#upstream).
- **A search with vectors takes 2 to 4 s and about 800 MB.** That is an MCP recall or a CLI `search`, each time, not only the first: most of it is `ReadRecords` unpacking the whole record log, then the query embedding. Hooks never read the vectors. `deja search --no-embed` takes about 0.1 s.
- **Another model or passage prefix embeds everything again:** about 16M tokens and 25 minutes at 72k records. Search stays lexical and says so while the client and the sidecar disagree.
- **A process started without `DEJA_EMBED_*` stays lexical.** gc agents run under the supervisor's environment, so check there before expecting vectors. `deja embed` itself must see the variables, hence `mise x` in the daemon.
- **The key is not in mise's `[env]`.** A template there reads `MONGODB_API_KEY` when mise renders it. mise renders at activation, before fnox's first precmd, then keeps the result and may skip its first prompt, so the variable stays empty or stale. It would work only while a fnox secret named `MISE_*` happens to wake mise up.
- **A non-interactive shell has no key,** like every other fnox secret: nothing runs precmd there. Copy the daemon's `fnox exec -- ... sh -c` line.

## Upstream

Pin: 0.24.0 plus a local build.

- **The semantic floor is a fixed 0.55.** It drops about half of `voyage-4-large`'s right answers. [vshulcz/deja-vu#5970](https://github.com/vshulcz/deja-vu/issues/5970), fix in [vshulcz/deja-vu#5971](https://github.com/vshulcz/deja-vu/pull/5971), which adds `DEJA_EMBED_FLOOR`. The installed binary is v0.24.0 with that patch.
  - Check: is the PR merged and released under the same variable name. If the name changed, rename `DEJA_EMBED_FLOOR` in `config.linux.toml`.
  - If search misbehaves: `deja.orig-0.24.0` next to the binary is the release build. Move it back and drop the variable; everything but the floor stays the same.
  - When released: bump the pin with `mise upgrade`, which removes the local build, and drop this item and the local-build quirk above.
