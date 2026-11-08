# dotfiles

The machine's chezmoi dotfiles (source root `homedir/`): shell, editors, agent CLIs, the mise
toolchain and the services mise runs under pitchfork. Owns the city's runtime: the gc, bd and dolt
pins and the gc-supervisor daemons (`homedir/dot_config/mise/config.gc.toml`), the mise env list
(`miserc.toml`) and the `~/.gc` link to gc's home. Does not own the city's configuration (the city
repository) or the metropolis pack (rig gascity-packs).

Governs: `homedir/**` (rendered into `$HOME` by `chezmoi apply`); for the city `homedir/dot_config/mise/config.gc.toml`, `homedir/dot_config/mise/miserc.toml`, `homedir/symlink_dot_gc.tmpl`.
Interfaces: `chezmoi apply` renders `homedir/` into `$HOME`; mise reads `~/.config/mise/config*.toml` and resolves the toolchain every gc process runs; pitchfork runs the daemons (`pitchfork status|restart gc-supervisor`).
Useful for: bumping gc, bd or dolt, changing the supervisor daemon or its environment, machine-level tools and settings.
Depends on: nothing in this product.
