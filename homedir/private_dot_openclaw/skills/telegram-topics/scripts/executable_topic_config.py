#!/usr/bin/env python3
"""Patch OpenClaw Telegram topic routing after a topic id is known."""
from __future__ import annotations
import argparse, json, re, shutil, time
from pathlib import Path

CFG = Path.home() / ".openclaw" / "openclaw.json"
COMMENT_RE = re.compile(r"//.*?$|/\*.*?\*/", re.S | re.M)


def load(path: Path):
    return json.loads(COMMENT_RE.sub("", path.read_text()))


def save(path: Path, cfg: dict):
    shutil.copy2(path, path.with_suffix(path.suffix + f".bak.{int(time.time())}"))
    path.write_text(json.dumps(cfg, ensure_ascii=False, indent=2) + "\n")


def default_account_chat(cfg: dict, account: str | None, chat: str | None):
    accounts = cfg.get("channels", {}).get("telegram", {}).get("accounts", {})
    if account and chat:
        return account, chat
    candidates = []
    for aid, acfg in accounts.items():
        for cid in (acfg.get("groups") or {}):
            candidates.append((aid, str(cid)))
    if account:
        chats = [cid for aid, cid in candidates if aid == account]
        if len(chats) == 1:
            return account, chats[0]
    if chat:
        aids = [aid for aid, cid in candidates if cid == chat]
        if len(aids) == 1:
            return aids[0], chat
    if len(candidates) == 1:
        return candidates[0]
    raise SystemExit("Pass --account and --chat; config does not have exactly one Telegram forum group.")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("op", choices=["add", "remove"])
    ap.add_argument("topic_id", type=int)
    ap.add_argument("--agent", default="main", help="agentId for add; use opencode for coding topics")
    ap.add_argument("--account")
    ap.add_argument("--chat")
    ap.add_argument("--config", type=Path, default=CFG)
    args = ap.parse_args()

    cfg = load(args.config)
    account, chat = default_account_chat(cfg, args.account, args.chat)
    topic = str(args.topic_id)
    peer_id = f"{chat}:topic:{topic}"
    group = cfg.setdefault("channels", {}).setdefault("telegram", {}).setdefault("accounts", {}).setdefault(account, {}).setdefault("groups", {}).setdefault(chat, {})
    topics = group.setdefault("topics", {})
    bindings = cfg.setdefault("bindings", [])

    if args.op == "add":
        topics[topic] = {"agentId": args.agent}
        if not any(b.get("match", {}).get("peer", {}).get("id") == peer_id for b in bindings):
            bindings.append({"agentId": args.agent, "match": {"channel": "telegram", "accountId": account, "peer": {"kind": "group", "id": peer_id}}})
    else:
        topics.pop(topic, None)
        cfg["bindings"] = [b for b in bindings if b.get("match", {}).get("peer", {}).get("id") != peer_id]

    save(args.config, cfg)
    print(f"{args.op}: account={account} chat={chat} topic={topic}")


if __name__ == "__main__":
    main()
