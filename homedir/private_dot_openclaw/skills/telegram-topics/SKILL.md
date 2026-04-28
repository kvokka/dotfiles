---
name: telegram-topics
description: Manage OpenClaw Telegram forum topics for configured Telegram group accounts. Use when asked to create/delete/list/cleanup Telegram topics, route a topic to an agent, create Telegram topics for opencode/ACP project work, or distinguish OpenClaw ops topics from coding/OpenCode topics.
---

# Telegram Topics

Scope: Telegram forum topics only. Prefer the single configured Telegram account/group when exactly one exists.

Trusted sources only:

- `openclaw.json` config.
- Live Telegram Bot API responses.
- `$WORKDIR` for locating active project directories when creating coding/OpenCode topics.

Never use OpenClaw topic-name/session caches for topic discovery, drift, cleanup, or deletion. Cache may be empty on a new machine and may retain manually deleted topics.

Config map:

- `agents.list`: available agents and models/skills.
- `agents.list[].runtime.type="acp"`: ACP/OpenCode-capable configured agents, e.g. `opencode`.
- `channels.telegram.accounts.<account>.groups.<forumId>`: configured forum group and `topics`; topic keys are Telegram `message_thread_id` strings.
- `bindings`: route peer `<forumId>:topic:<topicId>` to an agent. `bindings[].type="acp"` creates persistent ACP/OpenCode conversation bindings.
- Telegram forum group id is `-100{peerID}`.

Topic kinds:

- **General/root topic**: topic `1`; Telegram's built-in topic. It always exists in a forum group and cannot be deleted.
- **OpenClaw ops topics**: normal OpenClaw chat, e.g. `main`, `fast`, `ops`; use route topics.
- **Coding/OpenCode topics**: Telegram topics bound to persistent ACP sessions, usually `agentId: opencode`, with `acp.cwd` set to a project directory under `$WORKDIR`. A project may have many topics; names must include a short unique suffix.

## Why there is no drift sync

Telegram Bot API cannot list all forum topics. Therefore OpenClaw cannot safely discover topics that a user created manually in Telegram. Do not implement or fake drift discovery. Manual topics are intentionally ignored; if a topic should be managed, create it through the `ops` agent / OpenClaw flow so its returned `topicId` can be added to config.

## Utility commands

The helper intentionally has only three user-facing operations:

```bash
scripts/topic_config.py check
scripts/topic_config.py add <topicId> --agent <agentId> [--name <topicName>]
scripts/topic_config.py add <topicId> --kind acp --agent opencode --project <projectName> [--task <shortTask>] [--name <topicName>]
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

### Create route topic / add routing

For normal OpenClaw topics:

1. Create the topic through OpenClaw, preferably via `ops`:
   `message` tool with `action="topic-create"`, `channel="telegram"`, `accountId`, `chatId`, `name`.
2. Route returned `topicId`:
   `scripts/topic_config.py add <topicId> --agent <agentId> --name <topicName> [--account ...] [--chat ...]`.
3. Restart/reload OpenClaw after config edits when possible.
4. Reply with topic name/id and agent id.

### Create OpenCode / ACP project topic

Use this when the user asks for an OpenCode/coding agent topic for a project.

1. Identify the project directory:
   - If the user gives an explicit path, use it as `--cwd` after verifying it exists.
   - If the user names a project, search immediate child directories under `$WORKDIR`.
   - Match exact normalized directory names first; fuzzy substring matches are acceptable only when unique.
   - If nothing matches or multiple projects match, ask the user to choose. Do not guess.
2. Ensure `agents.list[]` contains the requested ACP agent, normally `opencode`.
3. Create the Telegram forum topic through OpenClaw:
   `message` tool with `action="topic-create"`, `channel="telegram"`, `accountId`, `chatId`, `name`.
4. Add persistent ACP binding for the returned topic id:

```bash
scripts/topic_config.py add <topicId> --kind acp --agent opencode --project <projectName> [--task <shortTask>] [--name <topicName>]
```

Naming rule for ACP/OpenCode project topics:

- If user supplied an explicit topic name, use it.
- Otherwise use `<project> - <suffix>`.
- If a task/issue is provided, make the suffix a short task phrase, e.g. `solyanka - fix auth race`.
- If no task is provided, generate a stable short “adjective noun” suffix, e.g. `солянка - рыжий бобёр`, so multiple topics for one project do not collide.
- If the generated/stated name already exists in config, append the topic id to keep it unique.

If project resolution is ambiguous or no project matches, ask the user. With an explicit choice/path, rerun:

```bash
scripts/topic_config.py add <topicId> --kind acp --agent opencode --cwd /abs/path/to/project [--task <shortTask>] [--name <topicName>]
```

This writes a top-level binding shaped like:

```json5
{
  type: "acp",
  agentId: "opencode",
  match: {
    channel: "telegram",
    accountId: "group",
    peer: { kind: "group", id: "-1001234567890:topic:42" }
  },
  acp: {
    mode: "persistent",
    cwd: "/path/from/WORKDIR/project",
    label: "project-or-topic-name"
  }
}
```

The topic config entry should keep a readable `name`; it must not keep normal `agentId: main` routing for ACP topics because the persistent ACP binding owns that conversation. When converting an already-created OpenClaw topic to ACP, remove the stale normal route binding for the same peer and clear `topics.<topicId>.agentId`.

### Delete topic + routing

Topic `1` is Telegram's built-in General/root topic. It always exists in a forum group and cannot be deleted. Never suggest deleting topic `1`, never call `delete 1`, and never let cleanup remove its OpenClaw routing even if a probe looks odd.

When the user asks to delete a topic, the intended final state is **both**:

- the Telegram forum topic is deleted/closed in Telegram; and
- OpenClaw config routing/bindings for that topic are removed.

Do not treat config-only deletion as complete for an explicit user delete request. For non-General topics, first delete the topic in Telegram via the Telegram UI or Bot API `deleteForumTopic`, then remove OpenClaw routing/bindings explicitly:

```bash
scripts/topic_config.py delete <topicIds>
```

Examples:

```bash
scripts/topic_config.py delete 7
scripts/topic_config.py delete 7,58,67
```

If Telegram deletion fails or cannot be verified, say the task is blocked/partial and do not claim the topic was deleted just because config was edited.

### Cleanup workflow

There is no automatic `cleanup` command. Cleanup is a human-confirmed workflow:

1. Run `scripts/topic_config.py check`.
2. Inspect `missingInTelegram`.
3. Show the user the exact stale topic ids and names that would be removed from OpenClaw config.
4. Ask for explicit confirmation before any config edit.
5. Only after confirmation, run `scripts/topic_config.py delete <topicIds>`.

Do not delete topic `1`. If `check` reports topic `1` under `protectedGeneralTopicNotTouched`, treat that as a probe/config oddity, not as cleanup input.

If `check` reports `probeErrorsNotTouched`, do not edit config from that result; investigate the Telegram/API error first.

- `delete/remove` deletes non-General configured topics from Telegram first via Bot API `deleteForumTopic`; only after Telegram reports success or already-missing does it remove the topic route/bindings from `openclaw.json`. If Telegram deletion fails, config must remain untouched and the result must say `telegram_delete_failed`.

### OpenCode / oh-my-opencode agent selection

For coding ACP topics in this setup, the ACP harness id is still `opencode`, but the internal opencode agent must be `sisyphus`. Do not change the OpenClaw `agentId` to `sisyphus`; instead ensure the acpx command override is:

```json
{
  "plugins": {
    "entries": {
      "acpx": {
        "config": {
          "agents": {
            "opencode": {
              "command": "opencode --agent=sisyphus acp"
            }
          }
        }
      }
    }
  }
}
```

`opencode acp` itself does not expose `--agent` in subcommand help, but the top-level `opencode --agent=sisyphus acp` form is accepted and affects the ACP server before connection.
