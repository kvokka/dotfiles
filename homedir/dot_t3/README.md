# ~/.t3

T3 Code's home. chezmoi (kvokka/dotfiles, `homedir/dot_t3/`) writes everything here except the state T3 keeps
itself. This file lists what chezmoi cannot do, and how the coder profiles keep their plugins running.

## Layout

- `userdata/`: T3's settings (chezmoi merges its pinned keys into the file T3 rewrites) and themes.
- `claude-coder/`: the Claude provider instance. `settings.json` goes to Claude with `--settings`, `plugin/` holds
  its subagents (`coder:expert`, `coder:helper`) and goes with `--plugin-dir`, as an absolute path: T3 expands `~`
  only in `--settings`.
- `codex-coder/`: the `CODEX_HOME` of the Codex provider instance: `config.toml`, the subagent roles in `agents/`,
  and `bin/codex-trusted`, which T3 runs instead of `codex`.
- `workflows/`: T3 workflows (`review-loop`).

## Manual steps, once per machine

1. **The text generator's API key**: enter it in T3's Settings. T3 keeps it in `userdata/secrets`.
2. **T3 Connect**: `t3 connect`.
3. **The plugins of `claude-coder`**: Claude loads the plugins its `settings.json` enables from `~/.claude/plugins`,
   shared with the main Claude profile. `claude plugin list` shows what is installed; install what is missing:

   ```sh
   claude plugin marketplace add kvokka/kvokka-harness-plugins
   claude plugin marketplace add DietrichGebert/ponytail
   claude plugin install <name>@kvokka-harness-plugins    # each one enabledPlugins names
   claude plugin install ponytail@ponytail
   ```

4. **The plugins of `codex-coder`**: `CODEX_HOME=~/.t3/codex-coder codex plugin list` shows what is installed;
   install what `config.toml` enables and is missing:

   ```sh
   CODEX_HOME=~/.t3/codex-coder codex plugin marketplace upgrade
   CODEX_HOME=~/.t3/codex-coder codex plugin add <name>@<marketplace>
   ```

## codex-coder: plugin hooks

Codex runs a plugin's hook only while it is trusted, and skips it without a word otherwise. Each change of the
plugin, an update of the plugin included, makes its hooks untrusted again.

So T3 starts Codex through `codex-coder/bin/codex-trusted` (the instance's `binaryPath`; chezmoi fetches it from
kvokka-harness-plugins every day). At each start it trusts the hooks of the installed plugins of the marketplaces in
`CODEX_TRUSTED_MARKETPLACES` (the instance's `environment` in T3's settings: `kvokka-harness-plugins ponytail`), so
an update of those plugins needs no approval. A plugin that is not installed is left alone. When a hook stays
untrusted all the same, Codex is not started: the session fails with `codex-trusted: codex is not started` and the
cause on stderr. Fix the cause, or trust the hooks by hand with `CODEX_HOME=~/.t3/codex-coder codex`, then `/hooks`.

- The trust lives in `[hooks.state]` of `codex-coder/config.toml`, which `codex-trusted` writes. The config template
  pins none: pinned hashes go stale with the next plugin update. So a chezmoi apply drops the trust, the next start
  writes it again, and `chezmoi diff` shows those entries in between.
- A plugin from another marketplace goes into `config.toml` (the marketplace and the plugin) and its marketplace into
  `CODEX_TRUSTED_MARKETPLACES`; without the latter, its hooks wait for an approval in `/hooks`.
