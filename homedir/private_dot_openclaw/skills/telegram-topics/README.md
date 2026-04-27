# telegram-topics

Tiny OpenClaw skill for Telegram forum topics.

Trusted sources only: `openclaw.json` and live Telegram Bot API. No cache-based discovery.

Telegram Bot API cannot list all forum topics, so manual Telegram-created topics are intentionally not adopted. Create managed topics through `ops`/OpenClaw, then add the returned `topicId` to config.

Main helper:

```bash
scripts/topic_config.py check
scripts/topic_config.py add <topicId> --agent <agentId> [--name <topicName>]
scripts/topic_config.py delete <topicIds>
```

Notes:

- `<topicIds>` for `delete` may be comma-separated, e.g. `7,58,67`.
- Topic `1` is Telegram's built-in General/root topic; it is protected and cannot be deleted.
- `check` never changes config. Use it first, ask for explicit confirmation, then run `delete` for stale non-General topics only.
