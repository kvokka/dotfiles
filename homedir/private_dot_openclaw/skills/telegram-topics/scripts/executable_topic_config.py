#!/usr/bin/env python3
"""Manage OpenClaw Telegram forum topic routing using config + live Telegram API only.

Commands:
- add: add/update one configured topic route or ACP/OpenCode topic binding.
- delete: delete one or more non-General forum topics in Telegram, then remove their routes/bindings from config.
- check: probe configured topics in Telegram without changing config.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import time
import hashlib
import urllib.error
import urllib.parse
import urllib.request
import subprocess
from pathlib import Path
from typing import Any

CFG = Path.home() / ".openclaw" / "openclaw.json"
GENERAL_TOPIC_ID = "1"
DEFAULT_ACP_AGENT_ID = "opencode"
API_TIMEOUT_SECONDS = 15
SUFFIX_ADJECTIVES = [
    "red", "sleepy", "clever", "brisk", "mint", "wild", "cozy", "quick",
    "bold", "crooked", "lunar", "sharp", "dusty", "bright", "silent", "fuzzy",
]
SUFFIX_NOUNS = [
    "beaver", "badger", "raccoon", "seal", "hedgehog", "boar", "hamster", "penguin",
    "goose", "cat", "crab", "catfish", "beetle", "wombat", "gopher", "salmon",
]
CYRILLIC_TRANSLIT = {
    "а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "е": "e", "ё": "e", "ж": "zh", "з": "z",
    "и": "i", "й": "y", "к": "k", "л": "l", "м": "m", "н": "n", "о": "o", "п": "p", "р": "r",
    "с": "s", "т": "t", "у": "u", "ф": "f", "х": "h", "ц": "ts", "ч": "ch", "ш": "sh", "щ": "sch",
    "ъ": "", "ы": "y", "ь": "", "э": "e", "ю": "yu", "я": "ya",
}


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
            "runtime": agent.get("runtime"),
        }
        for agent in cfg.get("agents", {}).get("list", [])
        if agent.get("id")
    }


def require_agent(cfg: dict[str, Any], agent_id: str, acp: bool = False) -> None:
    agent = agents(cfg).get(agent_id)
    if not agent:
        raise SystemExit(f"Agent {agent_id!r} is not present in agents.list[].")
    if acp and (agent.get("runtime") or {}).get("type") != "acp":
        raise SystemExit(f"Agent {agent_id!r} exists but is not runtime.type=acp.")


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


def normalize_project_query(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", transliterate(value).casefold())


def transliterate(value: str) -> str:
    out: list[str] = []
    for char in value.casefold():
        out.append(CYRILLIC_TRANSLIT.get(char, char))
    return "".join(out)


def slugify(value: str) -> str:
    raw = transliterate(value)
    slug = re.sub(r"[^a-z0-9]+", "-", raw.casefold()).strip("-")
    slug = re.sub(r"-+", "-", slug)
    return slug or "task"


def run_git(args: list[str], cwd: str | Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(["git", *args], cwd=str(cwd), text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)


def git_output(args: list[str], cwd: str | Path) -> str:
    result = run_git(args, cwd)
    if result.returncode != 0:
        raise SystemExit(f"git {' '.join(args)} failed in {cwd}: {result.stderr.strip() or result.stdout.strip()}")
    return result.stdout.strip()


def git_root(path: str | Path) -> Path:
    root = git_output(["rev-parse", "--show-toplevel"], path)
    return Path(root).resolve()


def default_branch(repo: str | Path) -> str:
    for args in (["symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD"], ["branch", "--show-current"]):
        result = run_git(list(args), repo)
        if result.returncode == 0 and result.stdout.strip():
            value = result.stdout.strip()
            return value.removeprefix("origin/")
    for candidate in ("main", "master"):
        if run_git(["rev-parse", "--verify", candidate], repo).returncode == 0:
            return candidate
        if run_git(["rev-parse", "--verify", f"origin/{candidate}"], repo).returncode == 0:
            return candidate
    raise SystemExit(f"Cannot detect main branch in {repo}; pass --base-branch.")


def worktree_root_for_project(project_root: Path) -> Path:
    roots = [root for root in workdir_roots() if root.is_dir()]
    for root in roots:
        try:
            project_root.relative_to(root.resolve())
            return root.resolve()
        except ValueError:
            continue
    if roots:
        return roots[0].resolve()
    return project_root.parent.resolve()


def create_git_worktree(source_cwd: str, topic_name: str, branch: str | None, base_branch: str | None) -> dict[str, Any]:
    project_root = git_root(source_cwd)
    project_name = project_root.name
    suffix = slugify(branch or topic_name)
    project_slug = slugify(project_name)
    full_slug = suffix if suffix == project_slug or suffix.startswith(f"{project_slug}-") else slugify(f"{project_slug}-{suffix}")
    branch_name = full_slug
    worktree_path = worktree_root_for_project(project_root) / full_slug
    base = base_branch or default_branch(project_root)
    base_ref = f"origin/{base}" if run_git(["rev-parse", "--verify", f"origin/{base}"], project_root).returncode == 0 else base

    if worktree_path.exists():
        existing_root = git_root(worktree_path)
        existing_branch = git_output(["branch", "--show-current"], existing_root)
        if existing_branch != branch_name:
            raise SystemExit(f"Worktree path exists with branch {existing_branch!r}, expected {branch_name!r}: {worktree_path}")
        return {"source": str(project_root), "cwd": str(worktree_path), "branch": branch_name, "baseBranch": base, "created": False, "alreadyExisted": True}

    branch_exists = run_git(["rev-parse", "--verify", branch_name], project_root).returncode == 0
    args = ["worktree", "add"]
    if branch_exists:
        args += [str(worktree_path), branch_name]
    else:
        args += ["-b", branch_name, str(worktree_path), base_ref]
    result = run_git(args, project_root)
    if result.returncode != 0:
        raise SystemExit(f"git {' '.join(args)} failed in {project_root}: {result.stderr.strip() or result.stdout.strip()}")
    return {"source": str(project_root), "cwd": str(worktree_path), "branch": branch_name, "baseBranch": base, "created": True, "alreadyExisted": False}


def remove_git_worktree(cwd: str, branch: str | None = None, delete_branch: bool = True) -> dict[str, Any]:
    path = Path(cwd).expanduser().resolve()
    out: dict[str, Any] = {"cwd": str(path), "worktreeRemoved": False, "worktreeAlreadyMissing": False, "branchDeleted": False}
    if path.exists():
        repo_root = git_root(path)
        branch_name = branch or git_output(["branch", "--show-current"], repo_root)
        out["branch"] = branch_name
        common_dir = Path(git_output(["rev-parse", "--git-common-dir"], repo_root)).resolve()
        main_repo = common_dir.parent if common_dir.name == ".git" else common_dir
        result = run_git(["worktree", "remove", str(path)], main_repo)
        if result.returncode != 0:
            raise SystemExit(f"git worktree remove {path} failed: {result.stderr.strip() or result.stdout.strip()}")
        out["worktreeRemoved"] = True
        if delete_branch and branch_name:
            result = run_git(["branch", "-d", branch_name], main_repo)
            if result.returncode == 0:
                out["branchDeleted"] = True
            else:
                out["branchDeleteSkipped"] = result.stderr.strip() or result.stdout.strip()
        return out

    out["worktreeAlreadyMissing"] = True
    if branch:
        out["branch"] = branch
        roots = [root for root in workdir_roots() if root.is_dir()]
        for root in roots:
            for child in root.iterdir():
                if not (child / ".git").exists():
                    continue
                if run_git(["rev-parse", "--verify", branch], child).returncode == 0:
                    result = run_git(["branch", "-d", branch], child)
                    if result.returncode == 0:
                        out["branchDeleted"] = True
                    else:
                        out["branchDeleteSkipped"] = result.stderr.strip() or result.stdout.strip()
                    return out
    return out


def workdir_roots() -> list[Path]:
    value = os.environ.get("WORKDIR")
    if not value:
        return []
    return [Path(part).expanduser() for part in value.split(os.pathsep) if part.strip()]


def resolve_project_path(project: str | None, cwd: str | None) -> tuple[str | None, list[str]]:
    if cwd:
        path = Path(cwd).expanduser().resolve()
        if not path.is_dir():
            raise SystemExit(f"ACP cwd does not exist or is not a directory: {path}")
        return str(path), []
    if not project:
        return None, []
    roots = [root for root in workdir_roots() if root.is_dir()]
    if not roots:
        raise SystemExit("$WORKDIR is empty/unset or has no readable directories; pass --cwd explicitly.")
    query = normalize_project_query(project)
    exact: list[Path] = []
    fuzzy: list[Path] = []
    for root in roots:
        for child in root.iterdir():
            if not child.is_dir():
                continue
            normalized = normalize_project_query(child.name)
            if normalized == query:
                exact.append(child.resolve())
            elif query in normalized or normalized in query:
                fuzzy.append(child.resolve())
    matches = exact or fuzzy
    unique = sorted({str(path) for path in matches})
    if len(unique) == 1:
        return unique[0], []
    return None, unique


def binding_topic_key(binding: dict[str, Any]) -> TopicKey | None:
    match = binding.get("match", {}) or {}
    peer = match.get("peer", {}) or {}
    peer_id = str(peer.get("id", ""))
    if match.get("channel") != "telegram" or peer.get("kind") != "group" or ":topic:" not in peer_id:
        return None
    chat_id, topic_id = peer_id.rsplit(":topic:", 1)
    return str(match.get("accountId", "")), chat_id, topic_id


def binding_matches_topic(binding: dict[str, Any], account: str, chat: str, topic: str) -> bool:
    return binding_topic_key(binding) == (account, chat, topic)


def topic_bindings(cfg: dict[str, Any], account: str | None = None, chat: str | None = None) -> dict[TopicKey, list[dict[str, Any]]]:
    out: dict[TopicKey, list[dict[str, Any]]] = {}
    for binding in cfg.get("bindings", []) or []:
        key = binding_topic_key(binding)
        if not key:
            continue
        if (account and key[0] != account) or (chat and key[1] != chat):
            continue
        out.setdefault(key, []).append(binding)
    return out


def summarize_bindings(bindings: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [
        {
            "type": binding.get("type") or "route",
            "agentId": binding.get("agentId"),
            **({"acp": binding.get("acp")} if binding.get("acp") else {}),
            **({"comment": binding.get("comment")} if binding.get("comment") else {}),
        }
        for binding in bindings
    ]


def topic_display_name(topic_id: str, topic_cfg: Any) -> str:
    if isinstance(topic_cfg, dict):
        for field in ("name", "title", "label"):
            value = topic_cfg.get(field)
            if value:
                return str(value)
    if topic_id == GENERAL_TOPIC_ID:
        return "General"
    return f"topic {topic_id}"


def short_task_suffix(task: str) -> str:
    words = re.findall(r"[a-z0-9]+", slugify(task))
    if not words:
        return "task"
    suffix = "-".join(words[:4])
    return suffix[:48].strip("-_") or "task"


def adjective_noun_suffix(seed: str) -> str:
    digest = hashlib.sha256(seed.encode()).digest()
    adjective = SUFFIX_ADJECTIVES[digest[0] % len(SUFFIX_ADJECTIVES)]
    noun = SUFFIX_NOUNS[digest[1] % len(SUFFIX_NOUNS)]
    return f"{adjective} {noun}"


def project_display_name(project: str | None, cwd: str | None) -> str:
    if project:
        return Path(project).name
    if cwd:
        return Path(cwd).expanduser().resolve().name
    return "project"


def configured_topic_names(cfg: dict[str, Any], account: str, chat: str) -> set[str]:
    names: set[str] = set()
    group_topics = (
        cfg.get("channels", {})
        .get("telegram", {})
        .get("accounts", {})
        .get(account, {})
        .get("groups", {})
        .get(chat, {})
        .get("topics", {})
    )
    for topic_id, topic_cfg in (group_topics or {}).items():
        names.add(topic_display_name(str(topic_id), topic_cfg))
    return names


def unique_topic_name(cfg: dict[str, Any], account: str, chat: str, base: str, topic: str) -> str:
    existing = configured_topic_names(cfg, account, chat)
    if base not in existing:
        return base
    candidate = f"{base} #{topic}"
    if candidate not in existing:
        return candidate
    i = 2
    while f"{candidate}-{i}" in existing:
        i += 1
    return f"{candidate}-{i}"


def build_acp_topic_name(
    cfg: dict[str, Any],
    account: str,
    chat: str,
    topic: str,
    explicit_name: str | None,
    project: str | None,
    cwd: str,
    task: str | None,
) -> str:
    project_name = slugify(project_display_name(project, cwd))
    if explicit_name:
        explicit_slug = slugify(explicit_name)
        base = explicit_slug if explicit_slug == project_name or explicit_slug.startswith(f"{project_name}-") else f"{project_name}-{explicit_slug}"
        return unique_topic_name(cfg, account, chat, base, topic)
    suffix = short_task_suffix(task) if task else slugify(adjective_noun_suffix(f"{project_name}:{cwd}:{topic}"))
    base = suffix if suffix == project_name or suffix.startswith(f"{project_name}-") else f"{project_name}-{suffix}"
    return unique_topic_name(cfg, account, chat, base, topic)


def configured_topics(
    cfg: dict[str, Any],
    account: str | None = None,
    chat: str | None = None,
    only_topics: set[str] | None = None,
) -> dict[TopicKey, dict[str, Any]]:
    bindings = topic_bindings(cfg, account, chat)
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
                "bindings": summarize_bindings(bindings.get(key, [])),
            }
    for key, key_bindings in bindings.items():
        if only_topics and key[2] not in only_topics:
            continue
        out.setdefault(key, {"name": topic_display_name(key[2], None), "agentId": None, "bindings": summarize_bindings(key_bindings)})
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


def delete_forum_topic(token: str, chat: str, topic: str) -> dict[str, Any]:
    """Delete a Telegram forum topic.

    If Telegram already reports the topic as missing, treat the Telegram-side
    final state as satisfied so config cleanup can still complete.
    """
    result = api_call(token, "deleteForumTopic", {
        "chat_id": chat,
        "message_thread_id": int(topic),
    })
    description = str(result.get("description") or "")
    if result.get("ok"):
        return {"topicId": topic, "ok": True, "deletedInTelegram": True, "alreadyMissing": False}
    if is_missing_topic_error(description):
        return {"topicId": topic, "ok": True, "deletedInTelegram": False, "alreadyMissing": True, "description": description}
    return {"topicId": topic, "ok": False, "description": description or None, "raw": result}


def delete_forum_topics(token: str, chat: str, topics: list[str]) -> list[dict[str, Any]]:
    results = [delete_forum_topic(token, chat, topic) for topic in topics]
    failures = [item for item in results if not item.get("ok")]
    if failures:
        print_json({
            "action": "delete",
            "error": "telegram_delete_failed",
            "message": "Telegram topic deletion failed; config was not changed.",
            "telegram": results,
        })
        raise SystemExit(4)
    return results


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


def upsert_topic_config(
    cfg: dict[str, Any],
    account: str,
    chat: str,
    topic: str,
    agent: str | None,
    name: str | None,
    *,
    clear_agent: bool = False,
) -> None:
    group = topic_group(cfg, account, chat)
    topic_cfg: dict[str, Any] = {}
    if agent:
        topic_cfg["agentId"] = agent
    # Topic entries are schema-restricted routing options; do not store
    # human-readable names here. Use Telegram topic names and ACP binding labels.
    current = group.setdefault("topics", {}).get(topic)
    if isinstance(current, dict):
        current.update(topic_cfg)
        if clear_agent:
            current.pop("agentId", None)
        group["topics"][topic] = current
    else:
        if clear_agent:
            topic_cfg.pop("agentId", None)
        group.setdefault("topics", {})[topic] = topic_cfg


def upsert_route_binding(cfg: dict[str, Any], account: str, chat: str, topic: str, agent: str) -> None:
    peer_id = f"{chat}:topic:{topic}"
    bindings = cfg.setdefault("bindings", [])
    for binding in bindings:
        if binding_matches_topic(binding, account, chat, topic) and (binding.get("type") or "route") == "route":
            binding["agentId"] = agent
            binding.pop("acp", None)
            return
    bindings.append({
        "type": "route",
        "agentId": agent,
        "match": {
            "channel": "telegram",
            "accountId": account,
            "peer": {"kind": "group", "id": peer_id},
        },
    })


def remove_route_bindings_for_topic(cfg: dict[str, Any], account: str, chat: str, topic: str) -> None:
    cfg["bindings"] = [
        binding for binding in cfg.get("bindings", []) or []
        if not (binding_matches_topic(binding, account, chat, topic) and (binding.get("type") or "route") == "route")
    ]


def upsert_acp_binding(
    cfg: dict[str, Any],
    account: str,
    chat: str,
    topic: str,
    agent: str,
    cwd: str,
    label: str,
    mode: str,
    backend: str | None,
) -> None:
    peer_id = f"{chat}:topic:{topic}"
    acp_cfg: dict[str, Any] = {"mode": mode, "cwd": cwd, "label": label}
    if backend:
        acp_cfg["backend"] = backend

    # Topic creation through OpenClaw may have created a normal main/route binding first.
    # ACP topics must be owned by the ACP binding, so delete stale route bindings for
    # the same peer before adding/updating the acp binding.
    remove_route_bindings_for_topic(cfg, account, chat, topic)

    bindings = cfg.setdefault("bindings", [])
    for binding in bindings:
        if binding_matches_topic(binding, account, chat, topic) and binding.get("type") == "acp":
            binding["agentId"] = agent
            binding["acp"] = acp_cfg
            binding["comment"] = f"Telegram topic {topic} persistent ACP binding"
            return
    bindings.append({
        "type": "acp",
        "agentId": agent,
        "comment": f"Telegram topic {topic} persistent ACP binding",
        "match": {
            "channel": "telegram",
            "accountId": account,
            "peer": {"kind": "group", "id": peer_id},
        },
        "acp": acp_cfg,
    })


def delete_topics(cfg: dict[str, Any], account: str, chat: str, topics: list[str]) -> list[dict[str, Any]]:
    if GENERAL_TOPIC_ID in topics:
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
    removed_bindings = [
        binding for binding in cfg.get("bindings", []) or []
        if (
            (binding.get("match", {}) or {}).get("accountId") == account
            and ((binding.get("match", {}) or {}).get("peer", {}) or {}).get("id") in peer_ids
        )
    ]
    worktrees: dict[str, dict[str, Any]] = {}
    for binding in removed_bindings:
        if binding.get("type") != "acp":
            continue
        acp = binding.get("acp") or {}
        cwd = acp.get("cwd")
        if cwd:
            topic_id = str(((binding.get("match", {}) or {}).get("peer", {}) or {}).get("id", "")).rsplit(":topic:", 1)[-1]
            worktrees[topic_id] = remove_git_worktree(str(cwd), None, delete_branch=True)

    cfg["bindings"] = [
        binding for binding in cfg.get("bindings", []) or []
        if binding not in removed_bindings
    ]

    return [
        {
            "accountId": account,
            "chatId": chat,
            "topicId": topic,
            "name": configured_before.get((account, chat, topic), {}).get("name") or topic_display_name(topic, None),
            **({"worktree": worktrees[topic]} if topic in worktrees else {}),
        }
        for topic in topics
    ]


def print_json(data: Any) -> None:
    print(json.dumps(data, ensure_ascii=False, indent=2))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", type=Path, default=CFG)
    sub = parser.add_subparsers(dest="cmd", required=True)

    common_edit_args = argparse.ArgumentParser(add_help=False)
    common_edit_args.add_argument("--account")
    common_edit_args.add_argument("--chat")

    check_parser = sub.add_parser("check")
    check_parser.add_argument("--account")
    check_parser.add_argument("--chat")
    check_parser.add_argument("--token-env")
    check_parser.add_argument("--token")
    check_parser.add_argument("--topic", dest="topics", action="append", type=int, help="check only this topic id; repeatable")

    add_parser = sub.add_parser("add", parents=[common_edit_args])
    add_parser.add_argument("topic_id", type=int)
    add_parser.add_argument("--agent", default="main", help="agent id to route this topic to")
    add_parser.add_argument("--name", help="optional human-readable topic label/name for output and ACP binding label; not stored under topics.*")
    add_parser.add_argument("--kind", choices=["route", "acp"], default="route", help="route = normal OpenClaw topic; acp = persistent ACP/OpenCode topic")
    add_parser.add_argument("--project", help="project name to resolve under $WORKDIR for ACP cwd")
    add_parser.add_argument("--cwd", help="explicit ACP working directory")
    add_parser.add_argument("--label", help="ACP session label; defaults to generated topic name")
    add_parser.add_argument("--task", help="short task description used as topic-name suffix for ACP topics")
    add_parser.add_argument("--mode", choices=["persistent", "oneshot"], default="persistent", help="ACP session mode")
    add_parser.add_argument("--backend", help="optional ACP backend override")
    add_parser.add_argument("--branch", help="branch/worktree slug; defaults to topic name slug")
    add_parser.add_argument("--base-branch", help="main branch to base the coding worktree on; autodetected by default")
    add_parser.add_argument("--no-worktree", action="store_true", help="do not create a git worktree for ACP cwd (exceptional/debug use only)")

    delete_parser = sub.add_parser("delete", parents=[common_edit_args], aliases=["remove"])
    delete_parser.add_argument("topic_ids", help="comma-separated topic ids, e.g. 7 or 7,58,67")
    delete_parser.add_argument("--token-env")
    delete_parser.add_argument("--token")

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
        if args.kind == "acp":
            agent_id = args.agent if args.agent != "main" else DEFAULT_ACP_AGENT_ID
            require_agent(cfg, agent_id, acp=True)
            cwd, candidates = resolve_project_path(args.project, args.cwd)
            if candidates:
                print_json({
                    "error": "ambiguous_project",
                    "project": args.project,
                    "candidates": candidates,
                    "message": "More than one project matched under $WORKDIR; ask the user to choose one and rerun with --cwd.",
                })
                raise SystemExit(3)
            if not cwd:
                raise SystemExit("ACP topic requires --project <name> resolvable under $WORKDIR or explicit --cwd <path>.")
            topic_name = build_acp_topic_name(cfg, account, chat, topic, args.name or args.branch, args.project, cwd, args.task)
            label = args.label or topic_name
            worktree: dict[str, Any] | None = None
            acp_cwd = cwd
            if not args.no_worktree:
                worktree = create_git_worktree(cwd, topic_name, args.branch, args.base_branch)
                acp_cwd = str(worktree["cwd"])
            upsert_topic_config(cfg, account, chat, topic, None, None, clear_agent=True)
            upsert_acp_binding(cfg, account, chat, topic, agent_id, acp_cwd, label, args.mode, args.backend)
            save_config(args.config, cfg)
            print_json({
                "action": "add",
                "kind": "acp",
                "accountId": account,
                "chatId": chat,
                "topicId": topic,
                "name": topic_name,
                "agentId": agent_id,
                "acp": {"mode": args.mode, "cwd": acp_cwd, "label": label, **({"backend": args.backend} if args.backend else {})},
                **({"worktree": worktree} if worktree else {}),
            })
            return

        require_agent(cfg, args.agent)
        upsert_topic_config(cfg, account, chat, topic, args.agent, args.name)
        upsert_route_binding(cfg, account, chat, topic, args.agent)
        save_config(args.config, cfg)
        print_json({"action": "add", "kind": "route", "accountId": account, "chatId": chat, "topicId": topic, "label": args.name or topic_display_name(topic, None), "agentId": args.agent})
        return

    if args.cmd in {"delete", "remove"}:
        topics = parse_topic_ids(args.topic_ids)
        if GENERAL_TOPIC_ID in topics:
            raise SystemExit("Refusing to delete Telegram General topic 1: it is intrinsic, always present, and cannot be deleted.")
        token_value = bot_token(cfg, account, args.token_env, args.token)
        telegram_deleted = delete_forum_topics(token_value, chat, topics)
        deleted = delete_topics(cfg, account, chat, topics)
        save_config(args.config, cfg)
        print_json({"action": "delete", "telegram": telegram_deleted, "deleted": deleted})
        return


if __name__ == "__main__":
    main()
