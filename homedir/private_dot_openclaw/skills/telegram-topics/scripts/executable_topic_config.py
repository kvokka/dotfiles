#!/usr/bin/env python3
"""Inspect and clean OpenClaw Telegram forum topic routing using config + live Telegram API only."""
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

CFG = Path.home() / ".openclaw" / "openclaw.json"


def strip_jsonc(text: str) -> str:
    out = []
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


def load_jsonc(path: Path) -> dict:
    return json.loads(strip_jsonc(path.read_text()))


def save(path: Path, cfg: dict) -> None:
    shutil.copy2(path, path.with_suffix(path.suffix + f".bak.{int(time.time())}"))
    path.write_text(json.dumps(cfg, ensure_ascii=False, indent=2) + "\n")


def env_ref(value):
    if isinstance(value, dict) and value.get("source") == "env":
        return value.get("id")
    if isinstance(value, str) and value.startswith("${") and value.endswith("}"):
        return value[2:-1]
    return None


def bot_token(cfg: dict, account: str, token_env: str | None = None, token: str | None = None) -> str:
    if token:
        return token
    env_name = token_env
    if not env_name:
        tg = cfg.get("channels", {}).get("telegram", {})
        acct = (tg.get("accounts") or {}).get(account, {})
        env_name = env_ref(acct.get("botToken")) or env_ref(tg.get("botToken"))
    if not env_name:
        raise SystemExit("Cannot resolve bot token env; pass --token-env or --token.")
    val = os.environ.get(env_name)
    if not val:
        raise SystemExit(f"Env var {env_name} is empty/unset.")
    return val


def api_call(token: str, method: str, params: dict) -> dict:
    data = urllib.parse.urlencode(params).encode()
    req = urllib.request.Request(f"https://api.telegram.org/bot{token}/{method}", data=data)
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            return json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        try:
            return json.loads(e.read().decode())
        except Exception:
            return {"ok": False, "description": str(e)}


def agents(cfg: dict) -> dict:
    default_model = cfg.get("agents", {}).get("defaults", {}).get("model", {}).get("primary")
    return {
        a.get("id"): {
            "model": a.get("model") or default_model,
            "skills": a.get("skills"),
        }
        for a in cfg.get("agents", {}).get("list", [])
        if a.get("id")
    }


def groups(cfg: dict):
    accounts = cfg.get("channels", {}).get("telegram", {}).get("accounts", {}) or {}
    for account_id, account_cfg in accounts.items():
        for chat_id, group_cfg in (account_cfg.get("groups") or {}).items():
            yield str(account_id), str(chat_id), group_cfg


def default_account_chat(cfg: dict, account: str | None, chat: str | None) -> tuple[str, str]:
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


def binding_map(cfg: dict, account: str | None = None, chat: str | None = None) -> dict:
    out = {}
    for binding in cfg.get("bindings", []):
        match = binding.get("match", {})
        peer = match.get("peer", {})
        peer_id = str(peer.get("id", ""))
        account_id = str(match.get("accountId", ""))
        if match.get("channel") != "telegram" or peer.get("kind") != "group" or ":topic:" not in peer_id:
            continue
        chat_id, topic_id = peer_id.rsplit(":topic:", 1)
        if (account and account_id != account) or (chat and chat_id != chat):
            continue
        out[(account_id, chat_id, topic_id)] = binding.get("agentId")
    return out


def configured_topics(cfg: dict, account: str | None = None, chat: str | None = None) -> dict:
    bindings = binding_map(cfg, account, chat)
    out = {}
    for account_id, chat_id, group_cfg in groups(cfg):
        if (account and account_id != account) or (chat and chat_id != chat):
            continue
        for topic_id, topic_cfg in (group_cfg.get("topics") or {}).items():
            key = (account_id, chat_id, str(topic_id))
            out[key] = {
                "agentId": (topic_cfg or {}).get("agentId"),
                "bindingAgentId": bindings.get(key),
            }
    for key, agent_id in bindings.items():
        out.setdefault(key, {"agentId": None, "bindingAgentId": agent_id})
    return out


def probe_topic(token: str, chat: str, topic: str) -> dict:
    result = api_call(token, "sendChatAction", {
        "chat_id": chat,
        "message_thread_id": int(topic),
        "action": "typing",
    })
    desc = str(result.get("description", ""))
    ok = bool(result.get("ok"))
    missing = (not ok) and any(s in desc.lower() for s in [
        "message thread not found",
        "topic not found",
        "thread not found",
    ])
    return {"exists": ok, "ok": ok, "description": desc or None, "missing": missing}


def live_probe_configured(cfg: dict, account: str, chat: str, token_env: str | None, token: str | None) -> dict:
    token_value = bot_token(cfg, account, token_env, token)
    return {
        key: probe_topic(token_value, key[1], key[2])
        for key in configured_topics(cfg, account, chat)
    }


def print_list(cfg: dict, account: str, chat: str, token_env: str | None, token: str | None) -> None:
    configured = configured_topics(cfg, account, chat)
    live = live_probe_configured(cfg, account, chat, token_env, token)
    print(json.dumps({
        "agents": agents(cfg),
        "groups": [
            {"accountId": a, "chatId": c, "topics": g.get("topics", {})}
            for a, c, g in groups(cfg)
            if a == account and c == chat
        ],
        "bindings": [
            {"accountId": k[0], "chatId": k[1], "topicId": k[2], "agentId": v}
            for k, v in binding_map(cfg, account, chat).items()
        ],
        "liveProbes": [
            {"accountId": k[0], "chatId": k[1], "topicId": k[2], "configured": configured[k], "live": live[k]}
            for k in sorted(configured)
        ],
    }, ensure_ascii=False, indent=2))


def cleanup_report(cfg: dict, account: str, chat: str, token_env: str | None, token: str | None) -> tuple[dict, list, list]:
    configured = configured_topics(cfg, account, chat)
    live = live_probe_configured(cfg, account, chat, token_env, token)
    stale = sorted(k for k, v in live.items() if v.get("missing"))
    errors = sorted(k for k, v in live.items() if (not v.get("exists")) and (not v.get("missing")))
    report = {
        "staleInConfig": [
            {"accountId": k[0], "chatId": k[1], "topicId": k[2], "configured": configured[k], "live": live[k]}
            for k in stale
        ],
        "probeErrorsNotTouched": [
            {"accountId": k[0], "chatId": k[1], "topicId": k[2], "configured": configured[k], "live": live[k]}
            for k in errors
        ],
    }
    return report, stale, errors


def print_cleanup(cfg: dict, account: str, chat: str, token_env: str | None, token: str | None) -> None:
    report, _, _ = cleanup_report(cfg, account, chat, token_env, token)
    print(json.dumps(report, ensure_ascii=False, indent=2))


def upsert(cfg: dict, account: str, chat: str, topic: str, agent: str) -> None:
    group = cfg.setdefault("channels", {}).setdefault("telegram", {}).setdefault("accounts", {}).setdefault(account, {}).setdefault("groups", {}).setdefault(chat, {})
    group.setdefault("topics", {})[topic] = {"agentId": agent}
    peer_id = f"{chat}:topic:{topic}"
    bindings = cfg.setdefault("bindings", [])
    for binding in bindings:
        match = binding.get("match", {})
        if match.get("accountId") == account and match.get("peer", {}).get("id") == peer_id:
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


def remove(cfg: dict, account: str, chat: str, topic: str) -> None:
    cfg.get("channels", {}).get("telegram", {}).get("accounts", {}).get(account, {}).get("groups", {}).get(chat, {}).get("topics", {}).pop(topic, None)
    peer_id = f"{chat}:topic:{topic}"
    cfg["bindings"] = [
        b for b in cfg.get("bindings", [])
        if not (
            b.get("match", {}).get("accountId") == account
            and b.get("match", {}).get("peer", {}).get("id") == peer_id
        )
    ]


def main() -> None:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="cmd", required=True)

    for name in ["list", "cleanup"]:
        p = sub.add_parser(name)
        p.add_argument("--account")
        p.add_argument("--chat")
        p.add_argument("--config", type=Path, default=CFG)
        p.add_argument("--token-env")
        p.add_argument("--token")
        if name == "cleanup":
            p.add_argument("--dry-run", action="store_true")

    for name in ["add", "remove"]:
        p = sub.add_parser(name)
        p.add_argument("topic_id", type=int)
        p.add_argument("--account")
        p.add_argument("--chat")
        p.add_argument("--config", type=Path, default=CFG)
        if name == "add":
            p.add_argument("--agent", default="main", help="use opencode for coding topics")

    args = parser.parse_args()
    cfg = load_jsonc(args.config)
    account, chat = default_account_chat(cfg, args.account, args.chat)

    if args.cmd == "list":
        print_list(cfg, account, chat, args.token_env, args.token)
        return

    if args.cmd == "cleanup":
        report, stale, errors = cleanup_report(cfg, account, chat, args.token_env, args.token)
        print(json.dumps(report, ensure_ascii=False, indent=2))
        if errors:
            raise SystemExit("Probe errors occurred; refusing to edit config.")
        if not args.dry_run:
            for key in stale:
                remove(cfg, key[0], key[1], key[2])
            if stale:
                save(args.config, cfg)
        return

    topic = str(args.topic_id)
    if args.cmd == "add":
        upsert(cfg, account, chat, topic, args.agent)
    else:
        remove(cfg, account, chat, topic)
    save(args.config, cfg)
    print(f"{args.cmd}: account={account} chat={chat} topic={topic}")


if __name__ == "__main__":
    main()
