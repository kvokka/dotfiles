---
name: telegram-topics
description: Manage OpenClaw Telegram forum topics for configured Telegram group accounts. Use when asked to create/delete/list/cleanup Telegram topics, route a topic to an agent, or distinguish OpenClaw ops topics from coding/OpenCode topics.
---

# Telegram Topics

Scope: Telegram forum topics only. Prefer the single configured Telegram account/group when exactly one exists.

Trusted sources only:

- `openclaw.json` config.
- Live Telegram Bot API responses.

Never use OpenClaw topic-name/session caches for topic discovery, drift, cleanup, or deletion. Cache may be empty on a new machine and may retain manually deleted topics.

Config map:

- `agents.list`: available agents and models/skills.
- `channels.telegram.accounts.<account>.groups.<forumId>`: configured forum group and `topics`; topic keys are Telegram `message_thread_id` strings.
- `bindings`: route peer `<forumId>:topic:<topicId>` to an agent.
- Telegram forum group id is `-100{peerID}`.

Topic kinds:

- **OpenClaw ops topics**: normal OpenClaw chat, e.g. `main`, `fast`, `ops`.
- **Coding topics**: coding agents, e.g. `opencode`; details are site-specific unless documented.

## Why there is no drift sync

Telegram Bot API cannot list all forum topics. Therefore OpenClaw cannot safely discover topics that a user created manually in Telegram. Do not implement or fake drift discovery. Manual topics are intentionally ignored; if a topic should be managed, create it through the `ops` agent / OpenClaw flow so its returned `topicId` can be added to config.

## List

Run before edits:

```bash
scripts/topic_config.py list
```

It prints agents, configured groups/topics, bindings, and live probes for configured topics only.

## Create

1. Create topic through OpenClaw, preferably via `ops`:
   `message` tool with `action="topic-create"`, `channel="telegram"`, `accountId`, `chatId`, `name`.
2. Route returned `topicId`:
   `scripts/topic_config.py add <topicId> --agent <agentId> [--account ...] [--chat ...]`.
3. Restart/reload OpenClaw after config edits when possible.
4. Reply with topic name/id and agent id.

## Delete

OpenClaw has no first-class delete-topic tool. Delete in Telegram UI or Bot API `deleteForumTopic`, then use cleanup.

Explicit config-only removal is also available:

```bash
scripts/topic_config.py remove <topicId>
```

## Cleanup deleted topics

Cleanup only removes configured topics that live Telegram API confirms are gone. It never adds manually created topics.

Always dry-run first:

```bash
scripts/topic_config.py cleanup --dry-run
scripts/topic_config.py cleanup
```

If Telegram probe returns an ambiguous API error, cleanup refuses to edit config.
