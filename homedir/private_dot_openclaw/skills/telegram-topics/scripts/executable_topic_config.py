#!/usr/bin/env python3
"""Manage OpenClaw Telegram forum topic routing using config + live Telegram API only.

Commands:
- add: add/update one configured topic route.
- delete: remove one or more non-General topic routes from config.
- check: probe configured topics in Telegram without changing config.
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

CFG = Path.home() / ".openclaw" / "openclaw.json"
GENERAL_TOPIC_ID = "1"
API_TIMEOUT_SECONDS = 15

TopicKey = tuple[str, str, str]  # accountId, chatId, topicId


def strip_jsonc(text: str) -> str:
    """Remove // and /* */ comments while preserving string contents."""
    out: list[str] = []
    i = 0
    in_str = False
    esc = False
    while i < len(text):
        c = text[i]
        if in_str:
            out.append(c)
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_str = False
            i += 1
            continue
        if c == '"':
            in_str = True
            out.append(c)
            i += 1
            continue
        if c == "/" and i + 1 < len(text) and text[i + 1] == "/":
            j = text.find("\n", i)
            if j < 0:
                break
            out.append("\n")
            i = j + 1
            continue
        if c == "/" and i + 1 < len(text) and text[i + 1] == "*":
            j = text.find("*/", i + 2)
            i = len(text) if j < 0 else j + 2
            continue
        out.append(c)
        i += 1
    return "".join(out)


def load_jsonc(path: Path) -> dict[str, Any]:
    return json.loads(strip_jsonc(path.read_text()))


def save_config(path: Path, cfg: dict[str, Any]) -> None:
    shutil.copy2(path, path.with_suffix(path.suffix + f".bak.{int(time.time())}"))
    path.write_text(json.dumps(cfg, ensure_ascii=False, indent=2) + "\n")


def env_ref(value: Any) -> str | None:
    if isinstance(value, dict) and value.get("source") == "env":
        return value.get("id")
    if isinstance(value, str) and value.startswith("${") and value.endswith("}"):
        return value[2:-1]
    return None


def bot_token(cfg: dict[str, Any], account: str, token_env: str | None = None, token: str | None = None) -> str:
    if token:
        return token
    env_name = token_env
    if not env_name:
        telegram_cfg = cfg.get("channels", {}).get("telegram", {})
        account_cfg = (telegram_cfg.get("accounts") or {}).get(account, {})
        env_name = env_ref(account_cfg.get("botToken")) or env_ref(telegram_cfg.get("botToken"))
    if not env_name:
        raise SystemExit("Cannot resolve bot token env; pass --token-env or --token.")
    value = os.environ.get(env_name)
    if not value:
        raise SystemExit(f"Env var {env_name} is empty/unset.")
    return value


def api_call(token: str, method: str, params: dict[str, Any]) -> dict[str, Any]:
    data = urllib.parse.urlencode(params).encode()
    req = urllib.request.Request(f"https://api.telegram.org/bot{token}/{method}", data=data)
    try:
        with urllib.request.urlopen(req, timeout=API_TIMEOUT_SECONDS) as response:
            return json.loads(response.read().decode())
    except urllib.error.HTTPError as exc:
        try:
            return json.loads(exc.read().decode())
        except Exception:
            return {"ok": False, "description": str(exc)}
    except urllib.error.URLError as exc:
        return {"ok": False, "description": str(exc)}


def agents(cfg: dict[str, Any]) -> dict[str, dict[str, Any]]:
    default_model = cfg.get("agents", {}).get("defaults", {}).get("model", {}).get("primary")
    return {
        agent.get("id"): {
            "model": agent.get("model") or default_model,
            "skills": agent.get("skills"),
        }
        for agent in cfg.get("agents", {}).get("list", [])
        if agent.get("id")
    }


def groups(cfg: dict[str, Any]):
    accounts = cfg.get("channels", {}).get("telegram", {}).get("accounts", {}) or {}
    for account_id, account_cfg in accounts.items():
        for chat_id, group_cfg in (account_cfg.get("groups") or {}).items():
            yield str(account_id), str(chat_id), group_cfg or {}


def default_account_chat(cfg: dict[str, Any], account: str | None, chat: str | None) -> tuple[str, str]:
    if account and chat:
        return account, chat
    candidates = [(a, c) for a, c, _ in groups(cfg)]
    if account:
        chats = [c for a, c in candidates if a == account]
        if len(chats) == 1:
            return account, chats[0]
    if chat:
        accounts = [a for a, c in candidates if c == chat]
        if len(accounts) == 1:
            return accounts[0], chat
    if len(candidates) == 1:
        return candidates[0]
    raise SystemExit("Pass --account and --chat; config does not have exactly one Telegram forum group.")


def parse_topic_ids(raw: str) -> list[str]:
    topic_ids: list[str] = []
    for part in raw.split(","):
        topic_id = part.strip()
        if not topic_id:
            continue
        if not topic_id.isdigit() or int(topic_id) <= 0:
            raise SystemExit(f"Invalid topic id: {topic_id!r}")
        topic_ids.append(str(int(topic_id)))
    if not topic_ids:
        raise SystemExit("No topic ids provided.")
    seen: set[str] = set()
    unique: list[str] = []
    for topic_id in topic_ids:
        if topic_id not in seen:
            unique.append(topic_id)
            seen.add(topic_id)
    return unique


def binding_map(cfg: dict[str, Any], account: str | None = None, chat: str | None = None) -> dict[TopicKey, str | None]:
    out: dict[TopicKey, str | None] = {}
    for binding in cfg.get("bindings", []) or []:
        match = binding.get("match", {}) or {}
        peer = match.get("peer", {}) or {}
        peer_id = str(peer.get("id", ""))
        account_id = str(match.get("accountId", ""))
        if match.get("channel") != "telegram" or peer.get("kind") != "group" or ":topic:" not in peer_id:
            continue
        chat_id, topic_id = peer_id.rsplit(":topic:", 1)
        if (account and account_id != account) or (chat and chat_id != chat):
            continue
        out[(account_id, chat_id, topic_id)] = binding.get("agentId")
    return out


def topic_display_name(topic_id: str, topic_cfg: Any) -> str:
    if isinstance(topic_cfg, dict):
        for field in ("name", "title", "label"):
            value = topic_cfg.get(field)
            if value:
                return str(value)
    if topic_id == GENERAL_TOPIC_ID:
        return "General"
    return f"topic {topic_id}"


def configured_topics(
    cfg: dict[str, Any],
    account: str | None = None,
    chat: str | None = None,
    only_topics: set[str] | None = None,
) -> dict[TopicKey, dict[str, Any]]:
    bindings = binding_map(cfg, account, chat)
    out: dict[TopicKey, dict[str, Any]] = {}
    for account_id, chat_id, group_cfg in groups(cfg):
        if (account and account_id != account) or (chat and chat_id != chat):
            continue
        for topic_id, topic_cfg in (group_cfg.get("topics") or {}).items():
            topic_id = str(topic_id)
            if only_topics and topic_id not in only_topics:
                continue
            key = (account_id, chat_id, topic_id)
            out[key] = {
                "name": topic_display_name(topic_id, topic_cfg),
                "agentId": (topic_cfg or {}).get("agentId") if isinstance(topic_cfg, dict) else None,
                "bindingAgentId": bindings.get(key),
            }
    for key, agent_id in bindings.items():
        if only_topics and key[2] not in only_topics:
            continue
        out.setdefault(key, {"name": topic_display_name(key[2], None), "agentId": None, "bindingAgentId": agent_id})
    return out


def is_missing_topic_error(description: str) -> bool:
    desc = description.lower()
    return any(fragment in desc for fragment in [
        "message thread not found",
        "topic not found",
        "thread not found",
    ])


def probe_topic(token: str, chat: str, topic: str) -> dict[str, Any]:
    """Check a forum topic using sendMessage, then immediately delete the probe.

    Telegram Bot API has no read-only get/list forum topic endpoint. sendChatAction
    is also unreliable for deleted topics. A silent message + immediate delete is
    the smallest reliable existence check exposed by the Bot API.
    """
    result = api_call(token, "sendMessage", {
        "chat_id": chat,
        "message_thread_id": int(topic),
        "text": "OpenClaw topic existence probe; deleting immediately.",
        "disable_notification": "true",
    })
    description = str(result.get("description") or "")
    ok = bool(result.get("ok"))
    missing = (not ok) and is_missing_topic_error(description)
    out: dict[str, Any] = {
        "exists": ok,
        "ok": ok,
        "missing": missing,
        "description": description or None,
    }
    message_id = (result.get("result") or {}).get("message_id") if ok else None
    if message_id:
        delete_result = api_call(token, "deleteMessage", {"chat_id": chat, "message_id": message_id})
        out["probeMessageId"] = message_id
        out["probeDeleted"] = bool(delete_result.get("ok"))
        if not delete_result.get("ok"):
            out["deleteDescription"] = delete_result.get("description")
    return out


def live_probe_configured(
    cfg: dict[str, Any],
    account: str,
    chat: str,
    token_env: str | None,
    token: str | None,
    only_topics: set[str] | None = None,
) -> dict[TopicKey, dict[str, Any]]:
    token_value = bot_token(cfg, account, token_env, token)
    configured = configured_topics(cfg, account, chat, only_topics)
    return {key: probe_topic(token_value, key[1], key[2]) for key in sorted(configured)}


def check_report(
    cfg: dict[str, Any],
    account: str,
    chat: str,
    token_env: str | None,
    token: str | None,
    only_topics: set[str] | None = None,
) -> dict[str, Any]:
    configured = configured_topics(cfg, account, chat, only_topics)
    live = live_probe_configured(cfg, account, chat, token_env, token, only_topics)

    ok: list[dict[str, Any]] = []
    missing: list[dict[str, Any]] = []
    protected: list[dict[str, Any]] = []
    errors: list[dict[str, Any]] = []

    for key in sorted(configured):
        item = {
            "accountId": key[0],
            "chatId": key[1],
            "topicId": key[2],
            "name": configured[key].get("name"),
            "configured": configured[key],
            "live": live[key],
        }
        if live[key].get("exists"):
            ok.append(item)
        elif live[key].get("missing") and key[2] == GENERAL_TOPIC_ID:
            item["reason"] = "Telegram General topic id 1 is intrinsic and cannot be deleted; do not remove its routing."
            protected.append(item)
        elif live[key].get("missing"):
            missing.append(item)
        else:
            errors.append(item)

    return {
        "summary": {
            "configured": len(configured),
            "ok": len(ok),
            "missing": len(missing),
            "protectedGeneralTopicIssues": len(protected),
            "errors": len(errors),
        },
        "ok": ok,
        "missingInTelegram": missing,
        "protectedGeneralTopicNotTouched": protected,
        "probeErrorsNotTouched": errors,
    }


def topic_group(cfg: dict[str, Any], account: str, chat: str) -> dict[str, Any]:
    return (
        cfg.setdefault("channels", {})
        .setdefault("telegram", {})
        .setdefault("accounts", {})
        .setdefault(account, {})
        .setdefault("groups", {})
        .setdefault(chat, {})
    )


def upsert_topic(cfg: dict[str, Any], account: str, chat: str, topic: str, agent: str, name: str | None = None) -> None:
    group = topic_group(cfg, account, chat)
    topic_cfg: dict[str, Any] = {"agentId": agent}
    if name:
        topic_cfg["name"] = name
    elif topic == GENERAL_TOPIC_ID:
        topic_cfg["name"] = "General"
    group.setdefault("topics", {})[topic] = topic_cfg

    peer_id = f"{chat}:topic:{topic}"
    bindings = cfg.setdefault("bindings", [])
    for binding in bindings:
        match = binding.get("match", {}) or {}
        if match.get("accountId") == account and (match.get("peer") or {}).get("id") == peer_id:
            binding["agentId"] = agent
            return
    bindings.append({
        "agentId": agent,
        "match": {
            "channel": "telegram",
            "accountId": account,
            "peer": {"kind": "group", "id": peer_id},
        },
    })


def delete_topics(cfg: dict[str, Any], account: str, chat: str, topics: list[str]) -> list[dict[str, Any]]:
    protected = [topic for topic in topics if topic == GENERAL_TOPIC_ID]
    if protected:
        raise SystemExit("Refusing to delete Telegram General topic 1: it is intrinsic, always present, and cannot be deleted.")

    configured_before = configured_topics(cfg, account, chat, set(topics))
    group_topics = (
        cfg.get("channels", {})
        .get("telegram", {})
        .get("accounts", {})
        .get(account, {})
        .get("groups", {})
        .get(chat, {})
        .get("topics", {})
    )
    for topic in topics:
        group_topics.pop(topic, None)

    peer_ids = {f"{chat}:topic:{topic}" for topic in topics}
    cfg["bindings"] = [
        binding for binding in cfg.get("bindings", []) or []
        if not (
            (binding.get("match", {}) or {}).get("accountId") == account
            and ((binding.get("match", {}) or {}).get("peer", {}) or {}).get("id") in peer_ids
        )
    ]

    return [
        {
            "accountId": account,
            "chatId": chat,
            "topicId": topic,
            "name": configured_before.get((account, chat, topic), {}).get("name") or topic_display_name(topic, None),
        }
        for topic in topics
    ]


def print_json(data: Any) -> None:
    print(json.dumps(data, ensure_ascii=False, indent=2))


def main() -> None:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="cmd", required=True)

    common_edit_args = argparse.ArgumentParser(add_help=False)
    common_edit_args.add_argument("--account")
    common_edit_args.add_argument("--chat")
    common_edit_args.add_argument("--config", type=Path, default=CFG)

    check_parser = sub.add_parser("check")
    check_parser.add_argument("--account")
    check_parser.add_argument("--chat")
    check_parser.add_argument("--config", type=Path, default=CFG)
    check_parser.add_argument("--token-env")
    check_parser.add_argument("--token")
    check_parser.add_argument("--topic", dest="topics", action="append", type=int, help="check only this topic id; repeatable")

    add_parser = sub.add_parser("add", parents=[common_edit_args])
    add_parser.add_argument("topic_id", type=int)
    add_parser.add_argument("--agent", default="main", help="agent id to route this topic to")
    add_parser.add_argument("--name", help="optional human-readable topic name stored in config")

    delete_parser = sub.add_parser("delete", parents=[common_edit_args], aliases=["remove"])
    delete_parser.add_argument("topic_ids", help="comma-separated topic ids, e.g. 7 or 7,58,67")

    args = parser.parse_args()
    cfg = load_jsonc(args.config)
    account, chat = default_account_chat(cfg, args.account, args.chat)

    if args.cmd == "check":
        only_topics = {str(t) for t in (args.topics or [])} or None
        report = check_report(cfg, account, chat, args.token_env, args.token, only_topics)
        print_json(report)
        if report["summary"]["errors"]:
            raise SystemExit(2)
        if report["summary"]["missing"]:
            raise SystemExit(1)
        return

    if args.cmd == "add":
        topic = str(args.topic_id)
        if int(topic) <= 0:
            raise SystemExit(f"Invalid topic id: {topic!r}")
        upsert_topic(cfg, account, chat, topic, args.agent, args.name)
        save_config(args.config, cfg)
        print_json({"action": "add", "accountId": account, "chatId": chat, "topicId": topic, "name": args.name or topic_display_name(topic, None), "agentId": args.agent})
        return

    if args.cmd in {"delete", "remove"}:
        topics = parse_topic_ids(args.topic_ids)
        deleted = delete_topics(cfg, account, chat, topics)
        save_config(args.config, cfg)
        print_json({"action": "delete", "deleted": deleted})
        return


if __name__ == "__main__":
    main()
