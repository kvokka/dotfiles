## Bug scan: `ubs`

Before every commit run `ubs $(git diff --name-only --cached)` on the staged files; exit 0 means clean. Fix real findings at the root cause and re-run until it passes; the repository's pre-commit hook runs it as well, so never bypass it with `--no-verify`.
