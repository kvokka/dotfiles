# telegram-topics

Tiny OpenClaw skill for Telegram forum topics.

Trusted sources only: `openclaw.json`, live Telegram Bot API, and `$WORKDIR` for resolving active project directories. No cache-based discovery.

Telegram Bot API cannot list all forum topics, so manual Telegram-created topics are intentionally not adopted. Create managed topics through `ops`/OpenClaw, then add the returned `topicId` to config.

Main helper:

```bash
scripts/topic_config.py check
scripts/topic_config.py add <topicId> --agent <agentId> [--name <topicName>]
scripts/topic_config.py add <topicId> --kind acp --agent opencode --project <projectName> [--task <shortTask>] [--name <topicName>]
scripts/topic_config.py delete <topicIds>
```

Notes:

- `<topicIds>` for `delete` may be comma-separated, e.g. `7,58,67`.
- Topic `1` is Telegram's built-in General/root topic; it is protected and cannot be deleted.
- `check` never changes config. Use it first, ask for explicit confirmation, then run `delete` for stale non-General topics only.
- OpenCode topics use top-level `bindings[].type="acp"` with `peer.id="<chatId>:topic:<topicId>"` and `acp.cwd` set to a project directory under `$WORKDIR` or an explicit `--cwd`.
- OpenCode topic names are `<project> - <suffix>` unless `--name` is explicit. `--task` supplies a short suffix; without it the helper generates an adjective+noun suffix like `солянка - рыжий бобёр` so one project can have multiple unique topics.
- Converting a just-created OpenClaw topic to ACP clears stale `agentId: main` from topic config and removes normal route bindings for the same peer; the ACP binding must own that conversation.
