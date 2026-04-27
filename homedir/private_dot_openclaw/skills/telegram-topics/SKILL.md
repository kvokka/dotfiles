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

- **General/root topic**: topic `1`; Telegram's built-in topic. It always exists in a forum group and cannot be deleted.
- **OpenClaw ops topics**: normal OpenClaw chat, e.g. `main`, `fast`, `ops`.
- **Coding topics**: coding agents, e.g. `opencode`; details are site-specific unless documented.

## Why there is no drift sync

Telegram Bot API cannot list all forum topics. Therefore OpenClaw cannot safely discover topics that a user created manually in Telegram. Do not implement or fake drift discovery. Manual topics are intentionally ignored; if a topic should be managed, create it through the `ops` agent / OpenClaw flow so its returned `topicId` can be added to config.

## Utility commands

The helper intentionally has only three user-facing operations:

```bash
scripts/topic_config.py check
scripts/topic_config.py add <topicId> --agent <agentId> [--name <topicName>]
scripts/topic_config.py delete <topicIds>
```

Where `<topicIds>` for `delete` may be comma-separated, e.g. `7,58,67`.

`remove` is kept only as a backwards-compatible alias for `delete`; prefer `delete` in docs and answers.

### Check

Run before edits:

```bash
scripts/topic_config.py check
```

It probes all configured topics and prints JSON with:

- `ok`: configured topics confirmed live in Telegram.
- `missingInTelegram`: configured non-General topics Telegram reports as missing.
- `protectedGeneralTopicNotTouched`: topic `1` oddities; never delete this route automatically.
- `probeErrorsNotTouched`: ambiguous errors; do not edit config from these.

The probe intentionally sends a silent probe message into each configured topic and immediately deletes it, because Telegram Bot API has no read-only topic lookup and `sendChatAction` can incorrectly return success for manually deleted topics.

To check one known topic without probing everything:

```bash
scripts/topic_config.py check --topic <topicId>
```

### Create / add routing

1. Create the topic through OpenClaw, preferably via `ops`:
   `message` tool with `action="topic-create"`, `channel="telegram"`, `accountId`, `chatId`, `name`.
2. Route returned `topicId`:
   `scripts/topic_config.py add <topicId> --agent <agentId> --name <topicName> [--account ...] [--chat ...]`.
3. Restart/reload OpenClaw after config edits when possible.
4. Reply with topic name/id and agent id.

### Delete routing

Topic `1` is Telegram's built-in General/root topic. It always exists in a forum group and cannot be deleted. Never suggest deleting topic `1`, never call `delete 1`, and never let cleanup remove its OpenClaw routing even if a probe looks odd.

OpenClaw has no first-class delete-topic tool for normal topics. Delete non-General topics in Telegram UI or Bot API `deleteForumTopic`, then remove their OpenClaw routing explicitly:

```bash
scripts/topic_config.py delete <topicIds>
```

Examples:

```bash
scripts/topic_config.py delete 7
scripts/topic_config.py delete 7,58,67
```

### Cleanup workflow

There is no automatic `cleanup` command. Cleanup is a human-confirmed workflow:

1. Run `scripts/topic_config.py check`.
2. Inspect `missingInTelegram`.
3. Show the user the exact stale topic ids and names that would be removed from OpenClaw config.
4. Ask for explicit confirmation before any config edit.
5. Only after confirmation, run `scripts/topic_config.py delete <topicIds>`.

Do not delete topic `1`. If `check` reports topic `1` under `protectedGeneralTopicNotTouched`, treat that as a probe/config oddity, not as cleanup input.

If `check` reports `probeErrorsNotTouched`, do not edit config from that result; investigate the Telegram/API error first.
