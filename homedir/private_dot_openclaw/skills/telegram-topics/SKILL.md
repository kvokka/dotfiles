---
name: telegram-topics
description: Manage OpenClaw Telegram forum topics for the default configured Telegram group account. Use when asked to create/delete Telegram topics, route a topic to an OpenClaw agent, or distinguish OpenClaw operation topics from coding/OpenCode topics.
---

# Telegram Topics

Scope: only Telegram forum topics. Prefer the single configured Telegram account/group when exactly one exists.

Topic kinds:

- **OpenClaw ops topics**: route normal OpenClaw chat to an agent such as `main`, `fast`, or `ops`.
- **Coding topics**: reserved for coding agents such as `opencode`; details may be site-specific, so do not invent extra workflow.

## Create

1. Resolve account/chat from `channels.telegram.accounts`: default to the only account with `groups` (currently `group`).
2. Call the message tool with `action="topic-create"`, `channel="telegram"`, `accountId`, `chatId`, and `name`.
3. Add the returned `topicId` to config routing:
   - `channels.telegram.accounts.<accountId>.groups.<chatId>.topics.<topicId> = { "agentId": "<agentId>" }`
   - add matching binding: peer id `<chatId>:topic:<topicId>`.
4. Restart/reload OpenClaw after editing config when possible. If restart/reload fails, still report that the Telegram topic was created and config was updated, but routing may require a manual gateway restart.
5. Final user-facing reply must be a short success/failure note. On success include topic name, topic id, agent id, and model under the hood. Example:
   - `Created tg topic: <name> (topicId <id>) → agent <agentId>, model <model>.`
   If routing/restart is incomplete, append one short caveat.

To find the model: read `agents.list[]` in the OpenClaw config for the chosen `agentId`; if absent, use `agents.defaults.model.primary`. If you cannot determine it, write `model unknown` rather than omitting it.

Helper: `scripts/topic_config.py add <topicId> --agent <agentId> [--account group] [--chat <chatId>]`.

## Delete

OpenClaw exposes create/edit topic actions, not a first-class delete-topic tool.

1. Delete the topic in Telegram UI, or call Telegram Bot API `deleteForumTopic` with the same bot/account token.
2. Remove that `topicId` from `channels.telegram.accounts.<accountId>.groups.<chatId>.topics` and matching `bindings` peer id.
3. Restart/reload OpenClaw after editing config when possible. If restart/reload fails, still report that the Telegram topic was deleted and config was cleaned, but the running gateway may retain stale routing until restart.
4. Final user-facing reply must be a short success/failure note. For delete, do not explain or preserve what was routed before. Example:
   - `Removed tg topic: <name/topicId>. Config cleared.`
   If Telegram deletion fails but config cleanup succeeds, say so plainly in one sentence.

Helper: `scripts/topic_config.py remove <topicId> [--account group] [--chat <chatId>]` cleans config only.
