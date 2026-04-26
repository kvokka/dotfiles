# telegram-topics

Tiny OpenClaw skill for Telegram forum topics.

Trusted sources only: `openclaw.json` and live Telegram Bot API. No cache-based discovery.

Telegram Bot API cannot list all forum topics, so manual Telegram-created topics are intentionally not adopted. Create managed topics through `ops`/OpenClaw, then add the returned `topicId` to config.

Main helper:

```bash
scripts/topic_config.py list
scripts/topic_config.py cleanup --dry-run
scripts/topic_config.py cleanup
scripts/topic_config.py add <topicId> --agent <agentId>
scripts/topic_config.py remove <topicId>
```
