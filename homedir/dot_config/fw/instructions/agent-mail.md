## Coordination: MCP Agent Mail

The MCP server `mcp-agent-mail` coordinates agents working in the same repository. Use the repository's absolute path as `project_key` and the task id (bead id) as the thread id.

1. Identity, once per session:
   - In an ntm pane (`$TMUX_PANE` is set and ntm spawned the session) you are already registered. The session start context names you (`Agent Mail: you are <name>`); otherwise `am agents resolve-pane --project <repo>` prints the name. Never call `register_agent` or `create_agent_identity` there; `macro_start_session` with `pane_id=$TMUX_PANE` returns the same name.
   - Anywhere else, register once: `ensure_project(human_key=<repo>)`, `register_agent(project_key, program, model, task_description)`. Keep the returned name for the whole session and commit with `AGENT_NAME=<name> git commit ...`, so the pre-commit guard knows your reservations are yours.
2. Reserve before editing: `file_reservation_paths(project_key, agent_name, ["src/**"], ttl_seconds=3600, exclusive=true, reason="br-123")`.
3. Talk in the task's thread: `send_message(..., thread_id="br-123", subject="[br-123] Start: ...")`, `fetch_inbox(project_key, agent_name)`, `acknowledge_message(project_key, agent_name, message_id)`.
4. Finish: `release_file_reservations(project_key, agent_name)` and a final `[br-123] Completed: ...` message.

`macro_start_session`, `macro_prepare_thread`, `macro_file_reservation_cycle` and `macro_contact_handshake` bundle these steps. `from_agent not registered` means the name is not registered for this `project_key`; `FILE_RESERVATION_CONFLICT` means another agent holds the path: narrow the pattern, wait for expiry, or reserve non-exclusively. Reservations are advisory, but the repository's pre-commit guard blocks commits touching files someone else reserved.
