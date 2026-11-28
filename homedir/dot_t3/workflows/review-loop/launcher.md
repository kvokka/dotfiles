# The result thread of a review loop

A review loop has ended. Open the thread where the owner picks up its result, and do nothing else: change no file and
run no command.

Call `t3_thread_launch` once, with:

- `title`: `{{title}}`
- `workspaceStrategy`: `{"type": "existing_worktree", "worktreePath": "{{worktree}}", "branch": "{{branch}}"}`
- `message`: the text inside `<message>` below, whole and unchanged, without the tags.

Leave out `projectId`, the model and the modes: the thread takes yours. Then submit the `threadId` and the `link` the
call returned.

<message>
{{result}}
</message>
